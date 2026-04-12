use chrono::{DateTime, Utc};
use taskwarrior_core::TaskStatus;
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CreateTaskRequest {
    pub id: Uuid,
    pub description: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TransitionTaskRequest {
    pub status: TaskStatus,
    pub changed_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskQuery {
    pub statuses: Vec<TaskStatus>,
    pub required_tag: Option<String>,
    pub due_before: Option<DateTime<Utc>>,
    pub include_waiting: bool,
    pub reference_time: DateTime<Utc>,
}
