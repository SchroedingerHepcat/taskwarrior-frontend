//! Backend service and HTTP API.

mod error;
mod http_api;
mod operations;
mod requests;
mod service;
mod storage;
mod sync;

pub use error::{ServiceError, ValidationError};
pub use http_api::{build_router, start_server};
pub use operations::{
    api_spec, healthcheck, ApiEndpoint, ApiMethod, HealthResponse,
    TaskListResponse, TaskResponse,
};
pub use requests::{
    AddDependencyRequest, CreateTaskRequest, TaskQuery, TaskSort,
    TransitionTaskRequest, UpdateTaskRequest,
};
pub use service::TaskService;
pub use storage::{InMemoryTaskRepository, TaskRepository};
pub use sync::{
    CompatibilityGateway, InMemorySyncCoordinator, PreparedTaskWrite,
    SyncCoordinator, TaskwarriorCompatibilityGateway,
};
