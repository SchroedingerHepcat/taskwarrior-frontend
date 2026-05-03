use crate::error::ServiceError;
use crate::requests::{
    AddDependencyRequest, CreateTaskRequest, TaskQuery, TaskSort,
    TransitionTaskRequest, UpdateTaskRequest,
};
use crate::storage::TaskRepository;
use crate::sync::{PreparedTaskWrite, SyncCoordinator};
use chrono::{DateTime, Utc};
use taskwarrior_core::Task;
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

        let mut tasks: Vec<Task> = self
            .repository
            .list()
            .await?
            .into_iter()
            .filter(|task| query.matches(task))
            .collect();
        sort_tasks(
            &mut tasks,
            query.sort,
            query.reference_time,
        );

        Ok(tasks)
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
        CreateTaskRequest, TaskQuery, TaskSort, TransitionTaskRequest,
        UpdateTaskRequest,
    };
    use crate::storage::TaskChampionTaskRepository;
    use crate::sync::InMemorySyncCoordinator;
    use chrono::{TimeZone, Utc};
    use taskwarrior_core::TaskStatus;
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    fn service(
    ) -> TaskService<TaskChampionTaskRepository, InMemorySyncCoordinator> {
        TaskService::new(
            TaskChampionTaskRepository::default(),
            InMemorySyncCoordinator::default(),
        )
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
                    wait: None,
                    clear_wait: false,
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
                statuses: vec![TaskStatus::Completed],
                required_tag: Some("home".to_string()),
                due_before: Some(timestamp(250)),
                include_waiting: true,
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
                    wait: None,
                    clear_wait: false,
                    add_annotation: None,
                    modified_at: timestamp(150),
                },
            )
            .await
            .unwrap();

        let loaded = service.get_task(task_id).await.unwrap();
        let queried = service
            .query_tasks(&TaskQuery {
                statuses: vec![TaskStatus::Pending],
                required_tag: Some("backend".to_string()),
                due_before: None,
                include_waiting: true,
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
}
