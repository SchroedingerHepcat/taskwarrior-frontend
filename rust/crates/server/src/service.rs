use crate::error::ServiceError;
use crate::requests::{
    AddDependencyRequest, CreateTaskRequest, TaskQuery, TransitionTaskRequest,
    UpdateTaskRequest,
};
use crate::storage::TaskRepository;
use crate::sync::{CompatibilityGateway, SyncCoordinator};
use taskwarrior_core::Task;
use uuid::Uuid;

pub struct TaskService<R, C, S> {
    repository: R,
    compatibility: C,
    sync: S,
}

impl<R, C, S> TaskService<R, C, S> {
    pub fn new(
        repository: R,
        compatibility: C,
        sync: S,
    ) -> Self {
        Self {
            repository,
            compatibility,
            sync,
        }
    }

    pub fn repository(&self) -> &R {
        &self.repository
    }

    pub fn sync(&self) -> &S {
        &self.sync
    }
}

impl<R, C, S> TaskService<R, C, S>
where
    R: TaskRepository,
    C: CompatibilityGateway,
    S: SyncCoordinator,
{
    pub fn create_task(
        &mut self,
        request: CreateTaskRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let task = Task::new(request.id, request.description.trim());

        self.persist(task)
    }

    pub fn update_task(
        &mut self,
        task_id: Uuid,
        request: UpdateTaskRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let mut task = self.load(task_id)?;
        request.apply_to(&mut task);

        self.persist(task)
    }

    pub fn transition_task(
        &mut self,
        task_id: Uuid,
        request: TransitionTaskRequest,
    ) -> Result<Task, ServiceError> {
        request.validate()?;

        let mut task = self.load(task_id)?;
        task.transition_status(request.status, request.changed_at);

        self.persist(task)
    }

    pub fn add_task_dependency(
        &mut self,
        task_id: Uuid,
        request: AddDependencyRequest,
    ) -> Result<Task, ServiceError> {
        request.validate_for_task(task_id)?;

        let mut task = self.load(task_id)?;
        task.add_dependency(request.dependency);

        self.persist(task)
    }

    pub fn query_tasks(
        &self,
        query: &TaskQuery,
    ) -> Result<Vec<Task>, ServiceError> {
        query.validate()?;

        Ok(self
            .repository
            .list()
            .into_iter()
            .filter(|task| query.matches(task))
            .collect())
    }

    fn load(
        &self,
        task_id: Uuid,
    ) -> Result<Task, ServiceError> {
        self.repository
            .get(task_id)
            .ok_or(ServiceError::NotFound(task_id))
    }

    fn persist(
        &mut self,
        task: Task,
    ) -> Result<Task, ServiceError> {
        let prepared = self.compatibility.prepare_task_write(&task)?;

        self.repository.upsert(task.clone());
        self.sync
            .record_task_write(prepared)
            .map_err(ServiceError::Sync)?;

        Ok(task)
    }
}

#[cfg(test)]
mod tests {
    use super::TaskService;
    use crate::error::{ServiceError, ValidationError};
    use crate::requests::{
        AddDependencyRequest, CreateTaskRequest, TaskQuery,
        TransitionTaskRequest, UpdateTaskRequest,
    };
    use crate::storage::{InMemoryTaskRepository, TaskRepository};
    use crate::sync::{
        InMemorySyncCoordinator, TaskwarriorCompatibilityGateway,
    };
    use chrono::{TimeZone, Utc};
    use taskwarrior_core::TaskStatus;
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    fn service() -> TaskService<
        InMemoryTaskRepository,
        TaskwarriorCompatibilityGateway,
        InMemorySyncCoordinator,
    > {
        TaskService::new(
            InMemoryTaskRepository::default(),
            TaskwarriorCompatibilityGateway,
            InMemorySyncCoordinator::default(),
        )
    }

    #[test]
    fn service_wires_create_update_transition_and_query_flows() {
        let mut service = service();
        let task_id = Uuid::from_u128(100);

        let created = service
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Inbox".to_string(),
            })
            .unwrap();

        let updated = service
            .update_task(
                task_id,
                UpdateTaskRequest {
                    description: Some("Inbox clarified".to_string()),
                    due: Some(timestamp(200)),
                    wait: None,
                    modified_at: timestamp(150),
                },
            )
            .unwrap();

        let completed = service
            .transition_task(
                task_id,
                TransitionTaskRequest {
                    status: TaskStatus::Completed,
                    changed_at: timestamp(300),
                },
            )
            .unwrap();

        let queried = service
            .query_tasks(&TaskQuery {
                statuses: vec![TaskStatus::Completed],
                required_tag: None,
                due_before: Some(timestamp(250)),
                include_waiting: true,
                reference_time: timestamp(400),
            })
            .unwrap();

        assert_eq!(created.description, "Inbox");
        assert_eq!(updated.description, "Inbox clarified");
        assert_eq!(updated.modified, Some(timestamp(150)));
        assert_eq!(completed.end, Some(timestamp(300)));
        assert_eq!(queried, vec![completed.clone()]);
        assert_eq!(service.sync().writes().len(), 3);
        assert!(service.sync().writes()[0].operation_count > 0);
    }

    #[test]
    fn service_records_dependency_updates_without_storage_leaks() {
        let mut service = service();
        let task_id = Uuid::from_u128(110);
        let dependency = Uuid::from_u128(111);

        service
            .create_task(CreateTaskRequest {
                id: task_id,
                description: "Depends".to_string(),
            })
            .unwrap();

        let updated = service
            .add_task_dependency(
                task_id,
                AddDependencyRequest { dependency },
            )
            .unwrap();

        assert!(updated.dependencies.contains(&dependency));
        assert_eq!(service.sync().writes().len(), 2);
    }

    #[test]
    fn service_rejects_invalid_input_before_persisting() {
        let mut service = service();

        let err = service
            .create_task(CreateTaskRequest {
                id: Uuid::from_u128(120),
                description: " ".to_string(),
            })
            .unwrap_err();

        assert_eq!(
            err,
            ServiceError::Validation(ValidationError::EmptyDescription,),
        );
        assert!(service.repository().list().is_empty());
        assert!(service.sync().writes().is_empty());
    }
}
