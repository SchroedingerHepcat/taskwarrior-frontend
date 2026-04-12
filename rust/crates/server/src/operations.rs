use crate::requests::{CreateTaskRequest, TaskQuery, TransitionTaskRequest};
use taskwarrior_compat::{decode_task, encode_task, CompatibilityError};
use taskwarrior_core::Task;
use uuid::Uuid;

pub fn healthcheck() -> &'static str {
    "ok"
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

pub fn add_task_dependency(
    task: &mut Task,
    dependency: Uuid,
) {
    task.add_dependency(dependency);
}

pub fn query_tasks(
    tasks: &[Task],
    query: &TaskQuery,
) -> Vec<Task> {
    tasks
        .iter()
        .filter(|task| {
            query.statuses.is_empty() || query.statuses.contains(&task.status)
        })
        .filter(|task| {
            query
                .required_tag
                .as_ref()
                .is_none_or(|tag| task.tags.contains(tag))
        })
        .filter(|task| {
            query.due_before.is_none_or(|due_before| {
                task.due.is_some_and(|due| due <= due_before)
            })
        })
        .filter(|task| {
            query.include_waiting || !task.is_waiting_at(query.reference_time)
        })
        .cloned()
        .collect()
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
        add_task_dependency, compat_round_trip, create_task, healthcheck,
        query_tasks, sample_task, transition_task,
    };
    use crate::requests::{
        CreateTaskRequest, TaskQuery, TransitionTaskRequest,
    };
    use chrono::{TimeZone, Utc};
    use taskwarrior_core::{Task, TaskStatus};
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

    #[test]
    fn product_facing_dependency_update_round_trips_through_compat() {
        let mut task = create_task(CreateTaskRequest {
            id: Uuid::from_u128(5),
            description: "Dependency from API".to_string(),
        });
        let dependency = Uuid::from_u128(6);

        add_task_dependency(&mut task, dependency);

        let decoded = compat_round_trip(&task).unwrap();

        assert!(decoded.dependencies.contains(&dependency));
    }

    #[test]
    fn product_facing_query_filters_by_status_tag_and_scheduling_shape() {
        let mut matching = Task::new(Uuid::from_u128(7), "matching");
        matching.add_tag("home");
        matching.due = Some(timestamp(100));

        let mut filtered_by_wait = Task::new(Uuid::from_u128(8), "waiting");
        filtered_by_wait.add_tag("home");
        filtered_by_wait.due = Some(timestamp(90));
        filtered_by_wait.wait = Some(timestamp(300));

        let mut filtered_by_status = Task::new(Uuid::from_u128(9), "done");
        filtered_by_status.add_tag("home");
        filtered_by_status
            .transition_status(TaskStatus::Completed, timestamp(50));

        let query = TaskQuery {
            statuses: vec![TaskStatus::Pending],
            required_tag: Some("home".to_string()),
            due_before: Some(timestamp(150)),
            include_waiting: false,
            reference_time: timestamp(200),
        };

        let tasks = vec![
            matching.clone(),
            filtered_by_wait,
            filtered_by_status,
        ];
        let result = query_tasks(&tasks, &query);

        assert_eq!(result, vec![matching]);
    }
}
