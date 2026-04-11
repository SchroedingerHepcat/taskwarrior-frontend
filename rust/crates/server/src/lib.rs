//! Server-facing API boundary placeholders for the spike.

use chrono::{DateTime, Utc};
use taskwarrior_compat::{decode_task, encode_task, CompatibilityError};
use taskwarrior_core::{Task, TaskStatus};
use uuid::Uuid;

pub fn healthcheck() -> &'static str {
    "ok"
}

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

pub fn create_task(request: CreateTaskRequest) -> Task {
    Task::new(request.id, request.description)
}

pub fn transition_task(
    task: &mut Task,
    request: TransitionTaskRequest,
) {
    task.transition_status(request.status, request.changed_at);
}

pub fn compat_round_trip(task: &Task) -> Result<Task, CompatibilityError> {
    let encoded = encode_task(task);
    decode_task(&encoded.task_data)
}

pub fn sample_task() -> Task {
    create_task(CreateTaskRequest {
        id: Uuid::from_u128(1),
        description: "Initial compatibility spike".to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::{
        compat_round_trip, create_task, healthcheck, sample_task,
        transition_task, CreateTaskRequest, TransitionTaskRequest,
    };
    use chrono::{TimeZone, Utc};
    use taskwarrior_core::TaskStatus;
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    #[test]
    fn healthcheck_is_stable() {
        assert_eq!(healthcheck(), "ok");
    }

    #[test]
    fn sample_task_is_constructed_via_compat_layer() {
        let task = sample_task();

        assert_eq!(task.id, Uuid::from_u128(1));
        assert_eq!(
            task.description,
            "Initial compatibility spike"
        );
    }

    #[test]
    fn create_task_returns_product_facing_core_task() {
        let task = create_task(CreateTaskRequest {
            id: Uuid::from_u128(2),
            description: "Create from API".to_string(),
        });

        assert_eq!(task.id, Uuid::from_u128(2));
        assert_eq!(task.description, "Create from API");
        assert_eq!(task.status, TaskStatus::Pending);
    }

    #[test]
    fn product_facing_task_creation_round_trips_through_compat() {
        let mut task = create_task(CreateTaskRequest {
            id: Uuid::from_u128(3),
            description: "Round trip from API".to_string(),
        });
        task.due = Some(timestamp(100));
        task.wait = Some(timestamp(200));
        task.set_user_defined_attribute("jira.id", "TW-3");

        let decoded = compat_round_trip(&task).unwrap();

        assert_eq!(decoded, task);
    }

    #[test]
    fn product_facing_transition_round_trips_through_compat() {
        let mut task = create_task(CreateTaskRequest {
            id: Uuid::from_u128(4),
            description: "Complete from API".to_string(),
        });

        transition_task(
            &mut task,
            TransitionTaskRequest {
                status: TaskStatus::Completed,
                changed_at: timestamp(300),
            },
        );

        let decoded = compat_round_trip(&task).unwrap();

        assert_eq!(decoded.status, TaskStatus::Completed);
        assert_eq!(decoded.modified, Some(timestamp(300)));
        assert_eq!(decoded.end, Some(timestamp(300)));
    }
}
