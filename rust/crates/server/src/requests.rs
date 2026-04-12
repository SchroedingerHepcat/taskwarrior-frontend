use crate::ValidationError;
use chrono::{DateTime, Utc};
use taskwarrior_core::Task;
use taskwarrior_core::TaskStatus;
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CreateTaskRequest {
    pub id: Uuid,
    pub description: String,
}

impl CreateTaskRequest {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if self.description.trim().is_empty() {
            return Err(ValidationError::EmptyDescription);
        }

        Ok(())
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct UpdateTaskRequest {
    pub description: Option<String>,
    pub due: Option<DateTime<Utc>>,
    pub wait: Option<DateTime<Utc>>,
    pub modified_at: DateTime<Utc>,
}

impl UpdateTaskRequest {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if self.description.is_none()
            && self.due.is_none()
            && self.wait.is_none()
        {
            return Err(ValidationError::MissingTaskChanges);
        }

        if self
            .description
            .as_ref()
            .is_some_and(|description| description.trim().is_empty())
        {
            return Err(ValidationError::EmptyDescription);
        }

        Ok(())
    }

    pub fn apply_to(
        &self,
        task: &mut Task,
    ) {
        if let Some(description) = &self.description {
            task.description = description.trim().to_string();
        }

        if let Some(due) = self.due {
            task.due = Some(due);
        }

        if let Some(wait) = self.wait {
            task.wait = Some(wait);
        }

        task.modified = Some(self.modified_at);
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransitionTaskRequest {
    pub status: TaskStatus,
    pub changed_at: DateTime<Utc>,
}

impl TransitionTaskRequest {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if matches!(self.status, TaskStatus::Unknown(_)) {
            return Err(ValidationError::UnknownStatusInput);
        }

        Ok(())
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AddDependencyRequest {
    pub dependency: Uuid,
}

impl AddDependencyRequest {
    pub fn validate_for_task(
        &self,
        task_id: Uuid,
    ) -> Result<(), ValidationError> {
        if self.dependency == task_id {
            return Err(ValidationError::SelfDependency(task_id));
        }

        Ok(())
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskQuery {
    pub statuses: Vec<TaskStatus>,
    pub required_tag: Option<String>,
    pub due_before: Option<DateTime<Utc>>,
    pub include_waiting: bool,
    pub reference_time: DateTime<Utc>,
}

impl TaskQuery {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if self
            .statuses
            .iter()
            .any(|status| matches!(status, TaskStatus::Unknown(_)))
        {
            return Err(ValidationError::UnknownStatusInput);
        }

        if self
            .required_tag
            .as_ref()
            .is_some_and(|tag| tag.trim().is_empty())
        {
            return Err(ValidationError::EmptyRequiredTag);
        }

        Ok(())
    }

    pub fn matches(
        &self,
        task: &Task,
    ) -> bool {
        (self.statuses.is_empty() || self.statuses.contains(&task.status))
            && self
                .required_tag
                .as_ref()
                .is_none_or(|tag| task.tags.contains(tag.trim()))
            && self.due_before.is_none_or(|due_before| {
                task.due.is_some_and(|due| due <= due_before)
            })
            && (self.include_waiting
                || !task.is_waiting_at(self.reference_time))
    }
}

#[cfg(test)]
mod tests {
    use super::{
        AddDependencyRequest, CreateTaskRequest, TaskQuery,
        TransitionTaskRequest, UpdateTaskRequest,
    };
    use crate::ValidationError;
    use chrono::{TimeZone, Utc};
    use taskwarrior_core::{Task, TaskStatus};
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    #[test]
    fn create_task_request_rejects_blank_description() {
        let request = CreateTaskRequest {
            id: Uuid::from_u128(1),
            description: "   ".to_string(),
        };

        assert_eq!(
            request.validate(),
            Err(ValidationError::EmptyDescription),
        );
    }

    #[test]
    fn update_task_request_requires_a_change() {
        let request = UpdateTaskRequest {
            description: None,
            due: None,
            wait: None,
            modified_at: timestamp(10),
        };

        assert_eq!(
            request.validate(),
            Err(ValidationError::MissingTaskChanges),
        );
    }

    #[test]
    fn transition_task_request_rejects_unknown_status_input() {
        let request = TransitionTaskRequest {
            status: TaskStatus::Unknown("custom".to_string()),
            changed_at: timestamp(20),
        };

        assert_eq!(
            request.validate(),
            Err(ValidationError::UnknownStatusInput),
        );
    }

    #[test]
    fn dependency_request_rejects_self_dependency() {
        let task_id = Uuid::from_u128(30);
        let request = AddDependencyRequest {
            dependency: task_id,
        };

        assert_eq!(
            request.validate_for_task(task_id),
            Err(ValidationError::SelfDependency(task_id)),
        );
    }

    #[test]
    fn query_matches_product_facing_task_fields() {
        let mut task = Task::new(Uuid::from_u128(40), "match me");
        task.add_tag("home");
        task.due = Some(timestamp(100));
        task.wait = Some(timestamp(150));

        let query = TaskQuery {
            statuses: vec![TaskStatus::Pending],
            required_tag: Some("home".to_string()),
            due_before: Some(timestamp(120)),
            include_waiting: false,
            reference_time: timestamp(140),
        };

        assert!(!query.matches(&task));

        let visible_query = TaskQuery {
            reference_time: timestamp(160),
            ..query
        };

        assert!(visible_query.matches(&task));
    }
}
