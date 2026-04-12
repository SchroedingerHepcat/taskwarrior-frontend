//! Transport-neutral backend API scaffold.

mod error;
mod operations;
mod requests;
mod service;
mod storage;
mod sync;

pub use error::{ServiceError, ValidationError};
pub use operations::{
    api_spec, handle_add_dependency, handle_create_task, handle_health,
    handle_query_tasks, handle_transition_task, handle_update_task,
    healthcheck, ApiEndpoint, ApiMethod, HealthResponse, TaskListResponse,
    TaskResponse,
};
pub use requests::{
    AddDependencyRequest, CreateTaskRequest, TaskQuery, TransitionTaskRequest,
    UpdateTaskRequest,
};
pub use service::TaskService;
pub use storage::{InMemoryTaskRepository, TaskRepository};
pub use sync::{
    CompatibilityGateway, InMemorySyncCoordinator, PreparedTaskWrite,
    SyncCoordinator, TaskwarriorCompatibilityGateway,
};
