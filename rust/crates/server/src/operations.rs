use crate::error::ServiceError;
use crate::requests::{
    AddDependencyRequest, CreateTaskRequest, TaskQuery, TransitionTaskRequest,
    UpdateTaskRequest,
};
use crate::service::TaskService;
use crate::storage::TaskRepository;
use crate::sync::{CompatibilityGateway, SyncCoordinator};
use taskwarrior_core::Task;
use uuid::Uuid;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ApiMethod {
    Get,
    Post,
    Patch,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ApiEndpoint {
    pub method: ApiMethod,
    pub path: &'static str,
    pub summary: &'static str,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HealthResponse {
    pub status: &'static str,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskResponse {
    pub task: Task,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskListResponse {
    pub tasks: Vec<Task>,
}

pub fn api_spec() -> &'static [ApiEndpoint] {
    &[
        ApiEndpoint {
            method: ApiMethod::Get,
            path: "/health",
            summary: "Health check",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks",
            summary: "Create task",
        },
        ApiEndpoint {
            method: ApiMethod::Patch,
            path: "/tasks/{id}",
            summary: "Update task fields",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/{id}/transition",
            summary: "Transition task status",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/{id}/dependencies",
            summary: "Add task dependency",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/query",
            summary: "Query tasks",
        },
    ]
}

pub fn healthcheck() -> &'static str {
    "ok"
}

pub fn handle_health() -> HealthResponse {
    HealthResponse {
        status: healthcheck(),
    }
}

pub fn handle_create_task<R, C, S>(
    service: &mut TaskService<R, C, S>,
    request: CreateTaskRequest,
) -> Result<TaskResponse, ServiceError>
where
    R: TaskRepository,
    C: CompatibilityGateway,
    S: SyncCoordinator,
{
    service
        .create_task(request)
        .map(|task| TaskResponse { task })
}

pub fn handle_update_task<R, C, S>(
    service: &mut TaskService<R, C, S>,
    task_id: Uuid,
    request: UpdateTaskRequest,
) -> Result<TaskResponse, ServiceError>
where
    R: TaskRepository,
    C: CompatibilityGateway,
    S: SyncCoordinator,
{
    service
        .update_task(task_id, request)
        .map(|task| TaskResponse { task })
}

pub fn handle_transition_task<R, C, S>(
    service: &mut TaskService<R, C, S>,
    task_id: Uuid,
    request: TransitionTaskRequest,
) -> Result<TaskResponse, ServiceError>
where
    R: TaskRepository,
    C: CompatibilityGateway,
    S: SyncCoordinator,
{
    service
        .transition_task(task_id, request)
        .map(|task| TaskResponse { task })
}

pub fn handle_add_dependency<R, C, S>(
    service: &mut TaskService<R, C, S>,
    task_id: Uuid,
    request: AddDependencyRequest,
) -> Result<TaskResponse, ServiceError>
where
    R: TaskRepository,
    C: CompatibilityGateway,
    S: SyncCoordinator,
{
    service
        .add_task_dependency(task_id, request)
        .map(|task| TaskResponse { task })
}

pub fn handle_query_tasks<R, C, S>(
    service: &TaskService<R, C, S>,
    request: TaskQuery,
) -> Result<TaskListResponse, ServiceError>
where
    R: TaskRepository,
    C: CompatibilityGateway,
    S: SyncCoordinator,
{
    service
        .query_tasks(&request)
        .map(|tasks| TaskListResponse { tasks })
}

#[cfg(test)]
mod tests {
    use super::{api_spec, handle_create_task, handle_health, ApiMethod};
    use crate::error::{ServiceError, ValidationError};
    use crate::requests::CreateTaskRequest;
    use crate::service::TaskService;
    use crate::storage::InMemoryTaskRepository;
    use crate::sync::{
        InMemorySyncCoordinator, TaskwarriorCompatibilityGateway,
    };
    use uuid::Uuid;

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
    fn api_spec_covers_health_and_task_operations() {
        let endpoints = api_spec();

        assert_eq!(endpoints.len(), 6);
        assert!(endpoints.contains(&super::ApiEndpoint {
            method: ApiMethod::Get,
            path: "/health",
            summary: "Health check",
        }));
        assert!(endpoints.contains(&super::ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/query",
            summary: "Query tasks",
        }));
    }

    #[test]
    fn health_handler_returns_stable_response() {
        assert_eq!(
            handle_health(),
            super::HealthResponse { status: "ok" },
        );
    }

    #[test]
    fn create_handler_reports_validation_failures() {
        let mut service = service();

        let err = handle_create_task(
            &mut service,
            CreateTaskRequest {
                id: Uuid::from_u128(1),
                description: " ".to_string(),
            },
        )
        .unwrap_err();

        assert_eq!(
            err,
            ServiceError::Validation(ValidationError::EmptyDescription,),
        );
    }
}
