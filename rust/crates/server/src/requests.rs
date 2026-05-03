use crate::ValidationError;
use chrono::{DateTime, Utc};
use std::collections::BTreeSet;
use taskwarrior_core::{Annotation, Task, TaskStatus};
use uuid::Uuid;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TaskSort {
    DueAsc,
    ModifiedDesc,
    DescriptionAsc,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CreateTaskRequest {
    pub id: Uuid,
    pub description: String,
    pub created_at: DateTime<Utc>,
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
    pub project: Option<String>,
    pub clear_project: bool,
    pub tags: Option<Vec<String>>,
    pub due: Option<DateTime<Utc>>,
    pub clear_due: bool,
    pub wait: Option<DateTime<Utc>>,
    pub clear_wait: bool,
    pub add_annotation: Option<String>,
    pub modified_at: DateTime<Utc>,
}

impl UpdateTaskRequest {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if self.description.is_none()
            && self.project.is_none()
            && !self.clear_project
            && self.tags.is_none()
            && self.due.is_none()
            && !self.clear_due
            && self.wait.is_none()
            && !self.clear_wait
            && self.add_annotation.is_none()
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

        if self
            .project
            .as_ref()
            .is_some_and(|project| project.trim().is_empty())
        {
            return Err(ValidationError::EmptyProject);
        }

        if self
            .add_annotation
            .as_ref()
            .is_some_and(|note| note.trim().is_empty())
        {
            return Err(ValidationError::EmptyAnnotation);
        }

        if let Some(tags) = &self.tags {
            if tags.iter().any(|tag| tag.trim().is_empty()) {
                return Err(ValidationError::EmptyTag);
            }
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

        if self.clear_project {
            task.project = None;
        } else if let Some(project) = &self.project {
            task.project = Some(project.trim().to_string());
        }

        if let Some(tags) = &self.tags {
            task.tags = normalized_tags(tags);
        }

        if self.clear_due {
            task.due = None;
        } else if let Some(due) = self.due {
            task.due = Some(due);
        }

        if self.clear_wait {
            task.wait = None;
        } else if let Some(wait) = self.wait {
            task.wait = Some(wait);
        }

        if let Some(note) = &self.add_annotation {
            task.add_annotation(Annotation::new(
                self.modified_at,
                note.trim(),
            ));
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
    pub sort: TaskSort,
}

impl TaskQuery {
    pub fn all(reference_time: DateTime<Utc>) -> Self {
        Self {
            statuses: Vec::new(),
            required_tag: None,
            due_before: None,
            include_waiting: true,
            reference_time,
            sort: TaskSort::DueAsc,
        }
    }

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

fn normalized_tags(tags: &[String]) -> BTreeSet<String> {
    tags.iter()
        .map(|tag| tag.trim().to_string())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::{
        AddDependencyRequest, CreateTaskRequest, TaskQuery, TaskSort,
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
            created_at: timestamp(10),
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
            project: None,
            clear_project: false,
            tags: None,
            due: None,
            clear_due: false,
            wait: None,
            clear_wait: false,
            add_annotation: None,
            modified_at: timestamp(10),
        };

        assert_eq!(
            request.validate(),
            Err(ValidationError::MissingTaskChanges),
        );
    }

    #[test]
    fn update_request_applies_project_tags_and_annotation() {
        let mut task = Task::new(Uuid::from_u128(2), "initial");
        let request = UpdateTaskRequest {
            description: Some("updated".to_string()),
            project: Some("frontend".to_string()),
            clear_project: false,
            tags: Some(vec![
                "home".to_string(),
                "next".to_string(),
            ]),
            due: Some(timestamp(20)),
            clear_due: false,
            wait: None,
            clear_wait: true,
            add_annotation: Some("added note".to_string()),
            modified_at: timestamp(30),
        };

        request.apply_to(&mut task);

        assert_eq!(task.description, "updated");
        assert_eq!(
            task.project,
            Some("frontend".to_string())
        );
        assert!(task.tags.contains("home"));
        assert_eq!(task.due, Some(timestamp(20)));
        assert_eq!(task.wait, None);
        assert_eq!(task.annotations.len(), 1);
        assert_eq!(task.modified, Some(timestamp(30)));
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
            sort: TaskSort::DueAsc,
        };

        assert!(!query.matches(&task));

        let visible_query = TaskQuery {
            reference_time: timestamp(160),
            ..query
        };

        assert!(visible_query.matches(&task));
    }
}
