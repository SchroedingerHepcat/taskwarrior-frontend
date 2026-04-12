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
