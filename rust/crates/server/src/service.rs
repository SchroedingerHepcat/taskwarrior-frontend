use crate::error::ServiceError;
use crate::requests::{
    AddDependencyRequest, BoardTransitionRequest, CreateTaskRequest, TaskQuery,
    TaskSort, TransitionTaskRequest, UpdateTaskRequest,
};
use crate::storage::TaskRepository;
use crate::sync::{
    PreparedTaskWrite, SyncAttempt, SyncCoordinator, SyncMode, SyncStatus,
};
use chrono::{DateTime, Utc};
use std::collections::BTreeSet;
use taskwarrior_core::{Task, TaskStatus};
use uuid::Uuid;

pub struct TaskService<R, S> {
    repository: R,
    sync: S,
}

impl<R, S> TaskService<R, S> {
    pub fn new(
        repository: R,
        sync: S,
    ) -> Self {
        Self { repository, sync }
    }

    pub fn repository(&self) -> &R {
        &self.repository
    }

    pub fn sync(&self) -> &S {
        &self.sync
    }
}

impl<R, S> TaskService<R, S>
where
    R: TaskRepository,
    S: SyncCoordinator,
{
    pub async fn create_task(
        &mut self,
        request: CreateTaskRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let mut task = Task::new(request.id, request.description.trim());
        task.entry = Some(request.created_at);
        task.modified = Some(request.created_at);

        self.persist(task).await
    }

    pub async fn get_task(
        &mut self,
        task_id: Uuid,
    ) -> Result<Task, ServiceError> {
        self.load(task_id).await
    }

    pub async fn update_task(
        &mut self,
        task_id: Uuid,
        request: UpdateTaskRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let mut task = self.load(task_id).await?;
        request.apply_to(&mut task);

        self.persist(task).await
    }

    pub async fn transition_task(
        &mut self,
        task_id: Uuid,
        request: TransitionTaskRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let mut task = self.load(task_id).await?;
        task.transition_status(request.status, request.changed_at);

        self.persist(task).await
    }

    pub async fn transition_board_lane(
        &mut self,
        task_id: Uuid,
        request: BoardTransitionRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let mut task = self.load(task_id).await?;
        request.apply_to(&mut task);

        self.persist(task).await
    }

    pub async fn add_task_dependency(
        &mut self,
        task_id: Uuid,
        request: AddDependencyRequest,
    ) -> Result<Task, ServiceError> {
        request.validate_for_task(task_id)?;

        let mut task = self.load(task_id).await?;
        task.add_dependency(request.dependency);

        self.persist(task).await
    }

    pub async fn query_tasks(
        &mut self,
        query: &TaskQuery,
    ) -> Result<Vec<Task>, ServiceError> {
        query.validate()?;

        let all_tasks = self.repository.list().await?;
        let completed = completed_task_ids(&all_tasks);
        let mut tasks: Vec<Task> = all_tasks
            .into_iter()
            .filter(|task| {
                query.matches_with_completed_dependencies(task, &completed)
            })
            .collect();
        sort_tasks(
            &mut tasks,
            query.sort,
            query.reference_time,
        );

        Ok(tasks)
    }

    pub async fn sync_tasks(&mut self) -> Result<SyncAttempt, ServiceError> {
        if matches!(self.sync.mode(), SyncMode::Disabled) {
            let attempt = SyncAttempt {
                status: SyncStatus::Disabled,
            };
            self.sync
                .record_sync_attempt(attempt.clone())
                .map_err(ServiceError::Sync)?;

            return Ok(attempt);
        }

        let config = self.sync.sync_config();
        let attempt = match self.repository.sync(config).await {
            Ok(report) => SyncAttempt {
                status: SyncStatus::Synced {
                    task_count: report.task_count,
                },
            },
            Err(error) => SyncAttempt {
                status: SyncStatus::Failed(error.to_string()),
            },
        };

        self.sync
            .record_sync_attempt(attempt.clone())
            .map_err(ServiceError::Sync)?;

        Ok(attempt)
    }

    async fn load(
        &mut self,
        task_id: Uuid,
    ) -> Result<Task, ServiceError> {
        self.repository
            .get(task_id)
            .await?
            .ok_or(ServiceError::NotFound(task_id))
    }

    async fn persist(
        &mut self,
        task: Task,
    ) -> Result<Task, ServiceError> {
        let stored = self.repository.upsert(task).await?;
        self.sync
            .record_task_write(PreparedTaskWrite {
                task_id: stored.task.id,
                operation_count: stored.operation_count,
            })
            .map_err(ServiceError::Sync)?;

        Ok(stored.task)
    }
}

fn completed_task_ids(tasks: &[Task]) -> BTreeSet<uuid::Uuid> {
    tasks
        .iter()
        .filter(|task| task.status == TaskStatus::Completed)
        .map(|task| task.id)
        .collect()
}

fn sort_tasks(
    tasks: &mut [Task],
    sort: TaskSort,
    reference_time: DateTime<Utc>,
) {
    match sort {
        TaskSort::DueAsc => {
            tasks.sort_by_key(|task| {
                (
                    task.due.unwrap_or(
                        reference_time + chrono::Duration::days(3650),
                    ),
                    task.description.clone(),
                )
            });
        }
        TaskSort::ModifiedDesc => {
            tasks.sort_by_key(|task| {
                std::cmp::Reverse((
                    task.modified.unwrap_or(reference_time),
                    task.description.clone(),
                ))
            });
        }
        TaskSort::DescriptionAsc => {
            tasks.sort_by_key(|task| task.description.clone());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::TaskService;
    use crate::error::{ServiceError, ValidationError};
    use crate::requests::{
        AddDependencyRequest, BoardLaneTransition, BoardTransitionRequest,
        CreateTaskRequest, TaskQuery, TaskQueryPreset, TaskSort,
        TransitionTaskRequest, UpdateTaskRequest,
    };
    use crate::storage::TaskChampionTaskRepository;
    use crate::sync::{InMemorySyncCoordinator, SyncStatus};
    use chrono::{TimeZone, Utc};
    use std::fs;
    use std::path::PathBuf;
    use taskwarrior_compat::{
        TaskChampionLocalSyncConfig, TaskChampionSyncConfig,
    };
    use taskwarrior_core::TaskStatus;
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    fn service(
    ) -> TaskService<TaskChampionTaskRepository, InMemorySyncCoordinator> {
        TaskService::new(
            TaskChampionTaskRepository::default(),
            InMemorySyncCoordinator::disabled(),
        )
    }

    fn sync_service(
        config: TaskChampionSyncConfig
    ) -> TaskService<TaskChampionTaskRepository, InMemorySyncCoordinator> {
        TaskService::new(
            TaskChampionTaskRepository::default(),
            InMemorySyncCoordinator::configured(config),
        )
    }

    fn temp_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "taskwarrior-frontend-server-{name}-{}",
            Uuid::new_v4()
        ))
    }

    #[tokio::test]
    async fn service_wires_create_update_transition_and_query_flows() {
        let mut service = service();
        let task_id = Uuid::from_u128(100);

        let created = service
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Inbox".to_string(),
                created_at: timestamp(100),
            })
            .await
            .unwrap();

        let updated = service
            .update_task(
                task_id,
                UpdateTaskRequest {
                    description: Some("Inbox clarified".to_string()),
                    project: Some("frontend".to_string()),
                    clear_project: false,
                    tags: Some(vec!["home".to_string()]),
                    due: Some(timestamp(200)),
                    clear_due: false,
                    scheduled: None,
                    clear_scheduled: false,
                    wait: None,
                    clear_wait: false,
                    recurrence: None,
                    clear_recurrence: false,
                    add_annotation: Some("first note".to_string()),
                    modified_at: timestamp(150),
                },
            )
            .await
            .unwrap();

        let completed = service
            .transition_task(
                task_id,
                TransitionTaskRequest {
                    status: TaskStatus::Completed,
                    changed_at: timestamp(300),
                },
            )
            .await
            .unwrap();

        let queried = service
            .query_tasks(&TaskQuery {
                preset: TaskQueryPreset::Custom,
                statuses: vec![TaskStatus::Completed],
                project: None,
                no_project: false,
                required_tag: Some("home".to_string()),
                no_tags: false,
                due_after: None,
                due_before: Some(timestamp(250)),
                scheduled_after: None,
                scheduled_before: None,
                wait_after: None,
                wait_before: None,
                include_waiting: true,
                include_scheduled: true,
                include_blocked: true,
                reference_time: timestamp(400),
                sort: TaskSort::DueAsc,
            })
            .await
            .unwrap();

        assert_eq!(created.entry, Some(timestamp(100)));
        assert_eq!(
            updated.project,
            Some("frontend".to_string())
        );
        assert_eq!(updated.annotations.len(), 1);
        assert_eq!(completed.end, Some(timestamp(300)));
        assert_eq!(queried, vec![completed.clone()]);
        assert_eq!(service.sync().writes().len(), 3);
        assert!(service.sync().writes()[0].operation_count > 0);
    }

    #[tokio::test]
    async fn service_returns_task_by_id() {
        let mut service = service();
        let task_id = Uuid::from_u128(101);

        service
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Find me".to_string(),
                created_at: timestamp(100),
            })
            .await
            .unwrap();

        let task = service.get_task(task_id).await.unwrap();

        assert_eq!(task.description, "Find me");
    }

    #[tokio::test]
    async fn service_reads_back_from_taskchampion_repository() {
        let mut service = service();
        let task_id = Uuid::from_u128(102);

        service
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Authoritative store".to_string(),
                created_at: timestamp(100),
            })
            .await
            .unwrap();
        service
            .update_task(
                task_id,
                UpdateTaskRequest {
                    description: Some("TaskChampion backed".to_string()),
                    project: Some("storage".to_string()),
                    clear_project: false,
                    tags: Some(vec!["backend".to_string()]),
                    due: None,
                    clear_due: false,
                    scheduled: None,
                    clear_scheduled: false,
                    wait: None,
                    clear_wait: false,
                    recurrence: None,
                    clear_recurrence: false,
                    add_annotation: None,
                    modified_at: timestamp(150),
                },
            )
            .await
            .unwrap();

        let loaded = service.get_task(task_id).await.unwrap();
        let queried = service
            .query_tasks(&TaskQuery {
                preset: TaskQueryPreset::Custom,
                statuses: vec![TaskStatus::Pending],
                project: None,
                no_project: false,
                required_tag: Some("backend".to_string()),
                no_tags: false,
                due_after: None,
                due_before: None,
                scheduled_after: None,
                scheduled_before: None,
                wait_after: None,
                wait_before: None,
                include_waiting: true,
                include_scheduled: true,
                include_blocked: true,
                reference_time: timestamp(200),
                sort: TaskSort::DescriptionAsc,
            })
            .await
            .unwrap();

        assert_eq!(
            loaded.description,
            "TaskChampion backed"
        );
        assert_eq!(
            loaded.project,
            Some("storage".to_string())
        );
        assert_eq!(queried, vec![loaded]);
    }

    #[tokio::test]
    async fn next_actions_query_excludes_waiting_and_blocked_tasks() {
        let mut service = service();
        let ready_id = Uuid::from_u128(103);
        let waiting_id = Uuid::from_u128(104);
        let blocked_id = Uuid::from_u128(105);
        let blocker_id = Uuid::from_u128(106);

        for (id, description) in [
            (ready_id, "Ready next action"),
            (waiting_id, "Waiting next action"),
            (blocked_id, "Blocked next action"),
            (blocker_id, "Blocking task"),
        ] {
            service
                .create_task(CreateTaskRequest {
                    id,
                    description: description.to_string(),
                    created_at: timestamp(100),
                })
                .await
                .unwrap();
        }

        service
            .update_task(
                waiting_id,
                UpdateTaskRequest {
                    description: None,
                    project: None,
                    clear_project: false,
                    tags: None,
                    due: None,
                    clear_due: false,
                    scheduled: None,
                    clear_scheduled: false,
                    wait: Some(timestamp(300)),
                    clear_wait: false,
                    recurrence: None,
                    clear_recurrence: false,
                    add_annotation: None,
                    modified_at: timestamp(110),
                },
            )
            .await
            .unwrap();
        service
            .add_task_dependency(
                blocked_id,
                AddDependencyRequest {
                    dependency: blocker_id,
                },
            )
            .await
            .unwrap();

        let next_actions = service
            .query_tasks(&TaskQuery::next_actions(timestamp(200)))
            .await
            .unwrap();

        assert_eq!(next_actions.len(), 2);
        assert_eq!(next_actions[0].id, blocker_id);
        assert_eq!(next_actions[1].id, ready_id);

        service
            .transition_task(
                blocker_id,
                TransitionTaskRequest {
                    status: TaskStatus::Completed,
                    changed_at: timestamp(250),
                },
            )
            .await
            .unwrap();
        let unblocked = service
            .query_tasks(&TaskQuery::next_actions(timestamp(260)))
            .await
            .unwrap();

        assert_eq!(unblocked.len(), 2);
        assert_eq!(unblocked[0].id, blocked_id);
        assert_eq!(unblocked[1].id, ready_id);
    }

    #[tokio::test]
    async fn board_lane_transition_updates_supported_task_fields() {
        let mut service = service();
        let task_id = Uuid::from_u128(107);
        service
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Board card".to_string(),
                created_at: timestamp(100),
            })
            .await
            .unwrap();

        let waiting = service
            .transition_board_lane(
                task_id,
                BoardTransitionRequest {
                    lane: BoardLaneTransition::Waiting,
                    wait_until: Some(timestamp(300)),
                    changed_at: timestamp(120),
                },
            )
            .await
            .unwrap();
        let completed = service
            .transition_board_lane(
                task_id,
                BoardTransitionRequest {
                    lane: BoardLaneTransition::Completed,
                    wait_until: None,
                    changed_at: timestamp(140),
                },
            )
            .await
            .unwrap();

        assert_eq!(waiting.wait, Some(timestamp(300)));
        assert_eq!(completed.status, TaskStatus::Completed);
        assert_eq!(completed.end, Some(timestamp(140)));
    }

    #[tokio::test]
    async fn service_rejects_invalid_input_before_persisting() {
        let mut service = service();

        let err = service
            .create_task(CreateTaskRequest {
                id: Uuid::from_u128(120),
                description: " ".to_string(),
                created_at: timestamp(10),
            })
            .await
            .unwrap_err();

        assert_eq!(
            err,
            ServiceError::Validation(ValidationError::EmptyDescription,),
        );
        assert!(service
            .query_tasks(&TaskQuery::all(timestamp(20)))
            .await
            .unwrap()
            .is_empty());
        assert!(service.sync().writes().is_empty());
    }

    #[tokio::test]
    async fn disabled_sync_records_disabled_attempt() {
        let mut service = service();
        let sync = service.sync_tasks().await.unwrap();

        assert_eq!(sync.status, SyncStatus::Disabled);
        assert_eq!(service.sync().attempts(), &[sync]);
    }

    #[tokio::test]
    async fn local_taskchampion_sync_moves_tasks_between_services() {
        let server_dir = temp_path("local-sync");
        fs::create_dir_all(&server_dir).unwrap();
        let sync_config =
            TaskChampionSyncConfig::Local(TaskChampionLocalSyncConfig {
                server_dir: server_dir.clone(),
            });
        let task_id = Uuid::from_u128(130);
        let mut source = sync_service(sync_config.clone());
        let mut target = sync_service(sync_config);

        source
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Sync through TaskChampion".to_string(),
                created_at: timestamp(100),
            })
            .await
            .unwrap();
        let source_sync = source.sync_tasks().await.unwrap();
        let target_sync = target.sync_tasks().await.unwrap();
        let queried = target
            .query_tasks(&TaskQuery::all(timestamp(200)))
            .await
            .unwrap();

        assert_eq!(
            source_sync.status,
            SyncStatus::Synced { task_count: 1 },
        );
        assert_eq!(
            target_sync.status,
            SyncStatus::Synced { task_count: 1 },
        );
        assert_eq!(queried.len(), 1);
        assert_eq!(
            queried[0].description,
            "Sync through TaskChampion"
        );

        let _ = fs::remove_dir_all(server_dir);
    }
}
