//! Backend service and HTTP API.

mod config;
mod error;
mod http_api;
mod operations;
mod requests;
mod service;
mod storage;
mod sync;

pub use config::{BackendConfig, UiStateConfig};
pub use error::{ServiceError, ValidationError};
pub use http_api::{
    build_router, build_router_with_state, start_server,
    start_server_with_config, AppState,
};
pub use operations::{
    api_spec, healthcheck, ApiEndpoint, ApiMethod, HealthResponse,
    TaskListResponse, TaskResponse,
};
pub use requests::{
    AddDependencyRequest, CreateTaskRequest, TaskQuery, TaskSort,
    TransitionTaskRequest, UpdateTaskRequest,
};
pub use service::TaskService;
pub use storage::{StoredTask, TaskChampionTaskRepository, TaskRepository};
pub use sync::{
    InMemorySyncCoordinator, PreparedTaskWrite, SyncAttempt, SyncCoordinator,
    SyncMode, SyncStatus,
};
