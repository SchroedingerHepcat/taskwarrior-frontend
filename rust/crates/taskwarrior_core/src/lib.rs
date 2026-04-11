//! Core task domain types for the compatibility spike.

use chrono::{DateTime, Utc};
use std::collections::{BTreeMap, BTreeSet};
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Annotation {
    pub entry: DateTime<Utc>,
    pub description: String,
}

impl Annotation {
    pub fn new(
        entry: DateTime<Utc>,
        description: impl Into<String>,
    ) -> Self {
        Self {
            entry,
            description: description.into(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TaskStatus {
    Pending,
    Completed,
    Deleted,
    Recurring,
    Unknown(String),
}

impl TaskStatus {
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Completed | Self::Deleted)
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Task {
    pub id: Uuid,
    pub description: String,
    pub status: TaskStatus,
    pub entry: Option<DateTime<Utc>>,
    pub modified: Option<DateTime<Utc>>,
    pub due: Option<DateTime<Utc>>,
    pub end: Option<DateTime<Utc>>,
    pub wait: Option<DateTime<Utc>>,
    pub dependencies: BTreeSet<Uuid>,
    pub annotations: Vec<Annotation>,
    pub tags: BTreeSet<String>,
    pub user_defined_attributes: BTreeMap<String, String>,
}

impl Task {
    pub fn new(
        id: Uuid,
        description: impl Into<String>,
    ) -> Self {
        Self {
            id,
            description: description.into(),
            status: TaskStatus::Pending,
            entry: None,
            modified: None,
            due: None,
            end: None,
            wait: None,
            dependencies: BTreeSet::new(),
            annotations: Vec::new(),
            tags: BTreeSet::new(),
            user_defined_attributes: BTreeMap::new(),
        }
    }

    pub fn is_waiting_at(
        &self,
        now: DateTime<Utc>,
    ) -> bool {
        self.wait.is_some_and(|wait| wait > now)
    }

    pub fn transition_status(
        &mut self,
        status: TaskStatus,
        changed_at: DateTime<Utc>,
    ) {
        self.status = status;
        self.modified = Some(changed_at);
        self.end = if self.status.is_terminal() {
            Some(changed_at)
        } else {
            None
        };
    }

    pub fn add_annotation(
        &mut self,
        annotation: Annotation,
    ) {
        self.annotations.push(annotation);
        self.annotations
            .sort_by_key(|annotation| annotation.entry);
    }

    pub fn add_tag(
        &mut self,
        tag: impl Into<String>,
    ) {
        self.tags.insert(tag.into());
    }

    pub fn add_dependency(
        &mut self,
        dependency: Uuid,
    ) {
        self.dependencies.insert(dependency);
    }

    pub fn remove_dependency(
        &mut self,
        dependency: Uuid,
    ) {
        self.dependencies.remove(&dependency);
    }

    pub fn set_user_defined_attribute(
        &mut self,
        key: impl Into<String>,
        value: impl Into<String>,
    ) {
        self.user_defined_attributes
            .insert(key.into(), value.into());
    }
}

#[cfg(test)]
mod tests {
    use super::{Annotation, Task, TaskStatus};
    use chrono::{TimeZone, Utc};
    use std::collections::{BTreeMap, BTreeSet};
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    #[test]
    fn constructs_task_with_pending_defaults() {
        let task = Task::new(
            Uuid::from_u128(1),
            "Compatibility spike",
        );

        assert_eq!(task.id, Uuid::from_u128(1));
        assert_eq!(task.description, "Compatibility spike");
        assert_eq!(task.status, TaskStatus::Pending);
        assert_eq!(task.entry, None);
        assert_eq!(task.modified, None);
        assert_eq!(task.due, None);
        assert_eq!(task.end, None);
        assert_eq!(task.wait, None);
        assert_eq!(task.dependencies, BTreeSet::new());
        assert_eq!(task.annotations, Vec::new());
        assert_eq!(task.tags, BTreeSet::new());
        assert_eq!(
            task.user_defined_attributes,
            BTreeMap::new()
        );
    }

    #[test]
    fn due_and_modified_fields_can_be_set_independently() {
        let mut task = Task::new(Uuid::from_u128(5), "Date test");
        task.modified = Some(timestamp(100));
        task.due = Some(timestamp(200));

        assert_eq!(task.modified, Some(timestamp(100)));
        assert_eq!(task.due, Some(timestamp(200)));
        assert_eq!(task.end, None);
        assert_eq!(task.wait, None);
    }

    #[test]
    fn dependencies_are_deduplicated_and_removable() {
        let mut task = Task::new(Uuid::from_u128(9), "Dependency test");
        let dep_a = Uuid::from_u128(10);
        let dep_b = Uuid::from_u128(11);

        task.add_dependency(dep_a);
        task.add_dependency(dep_a);
        task.add_dependency(dep_b);
        task.remove_dependency(dep_a);

        assert_eq!(
            task.dependencies,
            BTreeSet::from([dep_b])
        );
    }

    #[test]
    fn completing_task_sets_end_and_modified() {
        let mut task = Task::new(Uuid::from_u128(6), "Status test");

        task.transition_status(TaskStatus::Completed, timestamp(300));

        assert_eq!(task.status, TaskStatus::Completed);
        assert_eq!(task.modified, Some(timestamp(300)));
        assert_eq!(task.end, Some(timestamp(300)));
    }

    #[test]
    fn deleting_task_sets_end_and_modified() {
        let mut task = Task::new(Uuid::from_u128(7), "Delete test");

        task.transition_status(TaskStatus::Deleted, timestamp(400));

        assert_eq!(task.status, TaskStatus::Deleted);
        assert_eq!(task.modified, Some(timestamp(400)));
        assert_eq!(task.end, Some(timestamp(400)));
    }

    #[test]
    fn non_terminal_status_clears_end_and_updates_modified() {
        let mut task = Task::new(Uuid::from_u128(8), "Reopen test");
        task.transition_status(TaskStatus::Completed, timestamp(500));

        task.transition_status(TaskStatus::Pending, timestamp(600));

        assert_eq!(task.status, TaskStatus::Pending);
        assert_eq!(task.modified, Some(timestamp(600)));
        assert_eq!(task.end, None);
    }

    #[test]
    fn waiting_is_based_on_wait_timestamp() {
        let mut task = Task::new(Uuid::from_u128(2), "Wait test");
        task.wait = Some(timestamp(200));

        assert!(task.is_waiting_at(timestamp(100)));
        assert!(!task.is_waiting_at(timestamp(200)));
        assert!(!task.is_waiting_at(timestamp(300)));
    }

    #[test]
    fn annotations_are_kept_in_timestamp_order() {
        let mut task = Task::new(Uuid::from_u128(3), "Annotation test");
        task.add_annotation(Annotation::new(timestamp(300), "later"));
        task.add_annotation(Annotation::new(
            timestamp(100),
            "earlier",
        ));

        assert_eq!(
            task.annotations,
            vec![
                Annotation::new(timestamp(100), "earlier"),
                Annotation::new(timestamp(300), "later"),
            ],
        );
    }

    #[test]
    fn tags_and_user_defined_attributes_are_deduplicated_by_key() {
        let mut task = Task::new(Uuid::from_u128(4), "Metadata test");
        task.add_tag("home");
        task.add_tag("home");
        task.set_user_defined_attribute("jira.id", "TW-42");
        task.set_user_defined_attribute("jira.id", "TW-43");

        assert_eq!(
            task.tags,
            BTreeSet::from(["home".to_string()])
        );
        assert_eq!(
            task.user_defined_attributes,
            BTreeMap::from([(
                "jira.id".to_string(),
                "TW-43".to_string()
            )]),
        );
    }

    #[test]
    fn unknown_status_is_not_treated_as_terminal() {
        let status = TaskStatus::Unknown("blocked-elsewhere".to_string());

        assert!(!status.is_terminal());
        assert!(TaskStatus::Completed.is_terminal());
        assert!(TaskStatus::Deleted.is_terminal());
    }
}
