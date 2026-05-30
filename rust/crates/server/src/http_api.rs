use crate::config::{BackendConfig, UiStateConfig};
use crate::error::ServiceError;
use crate::operations::{
    api_spec, healthcheck, map_task, parse_status, HealthResponse,
    TaskListResponse, TaskResponse,
};
use crate::requests::{
    BoardLaneTransition, BoardTransitionRequest, CreateTaskRequest, TaskQuery,
    TaskQueryPreset, TaskSort, TransitionTaskRequest, UpdateTaskRequest,
};
use crate::service::TaskService;
use crate::storage::TaskChampionTaskRepository;
use crate::sync::InMemorySyncCoordinator;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post, put};
use axum::{Json, Router};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use taskwarrior_compat::{
    TaskChampionStorageConfig, TaskChampionSyncConfig, TaskChampionTaskStore,
};
use tokio::net::TcpListener;
use tokio::sync::Mutex;
use tower_http::cors::{Any, CorsLayer};
use uuid::Uuid;

type AppService =
    TaskService<TaskChampionTaskRepository, InMemorySyncCoordinator>;

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct SyncStatusResponse {
    pub state: String,
    pub last_attempt_at: Option<DateTime<Utc>>,
    pub error_summary: Option<String>,
    pub retry_available: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct HttpSyncState {
    state: SyncStatusKind,
    last_attempt_at: Option<DateTime<Utc>>,
    error_summary: Option<String>,
    retry_available: bool,
}

impl HttpSyncState {
    fn disabled() -> Self {
        Self {
            state: SyncStatusKind::Disabled,
            last_attempt_at: None,
            error_summary: None,
            retry_available: false,
        }
    }

    fn configured() -> Self {
        Self {
            state: SyncStatusKind::Configured,
            last_attempt_at: None,
            error_summary: None,
            retry_available: true,
        }
    }

    fn syncing(&self) -> Self {
        Self {
            state: SyncStatusKind::Syncing,
            last_attempt_at: self.last_attempt_at,
            error_summary: None,
            retry_available: false,
        }
    }

    fn succeeded(at: DateTime<Utc>) -> Self {
        Self {
            state: SyncStatusKind::Succeeded,
            last_attempt_at: Some(at),
            error_summary: None,
            retry_available: true,
        }
    }

    fn failed(
        at: DateTime<Utc>,
        error_summary: String,
    ) -> Self {
        Self {
            state: SyncStatusKind::Failed,
            last_attempt_at: Some(at),
            error_summary: Some(error_summary),
            retry_available: true,
        }
    }

    fn response(&self) -> SyncStatusResponse {
        SyncStatusResponse {
            state: self.state.api_value().to_string(),
            last_attempt_at: self.last_attempt_at,
            error_summary: self.error_summary.clone(),
            retry_available: self.retry_available,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum SyncStatusKind {
    Disabled,
    Configured,
    Syncing,
    Succeeded,
    Failed,
}

impl SyncStatusKind {
    fn api_value(self) -> &'static str {
        match self {
            Self::Disabled => "disabled",
            Self::Configured => "configured",
            Self::Syncing => "syncing",
            Self::Succeeded => "succeeded",
            Self::Failed => "failed",
        }
    }
}

#[derive(Clone)]
pub struct AppState {
    service: Arc<Mutex<AppService>>,
    saved_views: Arc<Mutex<BTreeMap<String, HttpSavedView>>>,
    dashboard_layouts: Arc<Mutex<BTreeMap<String, HttpDashboardLayout>>>,
    ui_state_path: Option<Arc<PathBuf>>,
    storage_config: TaskChampionStorageConfig,
    sync_config: TaskChampionSyncConfig,
    sync_status: Arc<Mutex<HttpSyncState>>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            service: Arc::new(Mutex::new(TaskService::new(
                TaskChampionTaskRepository::default(),
                InMemorySyncCoordinator::disabled(),
            ))),
            saved_views: Arc::new(Mutex::new(BTreeMap::new())),
            dashboard_layouts: Arc::new(Mutex::new(BTreeMap::new())),
            ui_state_path: None,
            storage_config: TaskChampionStorageConfig::InMemory,
            sync_config: TaskChampionSyncConfig::Disabled,
            sync_status: Arc::new(Mutex::new(HttpSyncState::disabled())),
        }
    }
}

impl AppState {
    pub async fn from_config(
        config: BackendConfig
    ) -> Result<Self, ServiceError> {
        let storage_config = config.storage.clone();
        let sync_config = config.sync.clone();
        let sync_status = if config.sync.is_enabled() {
            HttpSyncState::configured()
        } else {
            HttpSyncState::disabled()
        };
        let repository =
            TaskChampionTaskRepository::from_storage_config(config.storage)
                .await?;
        let sync = if config.sync.is_enabled() {
            InMemorySyncCoordinator::configured(config.sync)
        } else {
            InMemorySyncCoordinator::disabled()
        };
        let ui_state = load_ui_state(&config.ui_state)?;

        Ok(Self {
            service: Arc::new(Mutex::new(TaskService::new(
                repository, sync,
            ))),
            saved_views: Arc::new(Mutex::new(ui_state.saved_views)),
            dashboard_layouts: Arc::new(Mutex::new(ui_state.dashboard_layouts)),
            ui_state_path: ui_state.path.map(Arc::new),
            storage_config,
            sync_config,
            sync_status: Arc::new(Mutex::new(sync_status)),
        })
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct HttpCreateTaskRequest {
    pub description: String,
}

#[derive(Debug, Deserialize)]
pub struct HttpUpdateTaskRequest {
    pub description: Option<String>,
    pub project: Option<String>,
    pub clear_project: Option<bool>,
    pub tags: Option<Vec<String>>,
    pub due: Option<String>,
    pub clear_due: Option<bool>,
    pub scheduled: Option<String>,
    pub clear_scheduled: Option<bool>,
    pub wait: Option<String>,
    pub clear_wait: Option<bool>,
    pub recurrence: Option<HttpRecurrence>,
    pub clear_recurrence: Option<bool>,
    pub add_annotation: Option<String>,
    pub modified_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HttpRecurrence {
    pub recur: String,
    pub rtype: Option<String>,
    pub until: Option<String>,
    pub parent: Option<String>,
    pub mask: Option<String>,
    pub imask: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HttpTransitionTaskRequest {
    pub status: String,
    pub changed_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HttpBoardTransitionRequest {
    pub lane: String,
    pub wait_until: Option<String>,
    pub changed_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HttpTaskQueryRequest {
    pub preset: Option<String>,
    pub statuses: Option<Vec<String>>,
    pub project: Option<String>,
    pub no_project: Option<bool>,
    pub required_tag: Option<String>,
    pub no_tags: Option<bool>,
    pub due_after: Option<String>,
    pub due_before: Option<String>,
    pub scheduled_after: Option<String>,
    pub scheduled_before: Option<String>,
    pub wait_after: Option<String>,
    pub wait_before: Option<String>,
    pub include_waiting: Option<bool>,
    pub include_scheduled: Option<bool>,
    pub include_blocked: Option<bool>,
    pub reference_time: Option<String>,
    pub sort: Option<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
pub struct HttpSavedView {
    pub id: String,
    pub name: String,
    pub filter: HttpSavedViewFilter,
    pub updated_at: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
pub struct HttpSavedViewFilter {
    pub preset: Option<String>,
    pub statuses: Option<Vec<String>>,
    pub project: Option<String>,
    pub no_project: Option<bool>,
    pub required_tag: Option<String>,
    pub no_tags: Option<bool>,
    pub due_after: Option<String>,
    pub due_before: Option<String>,
    pub scheduled_after: Option<String>,
    pub scheduled_before: Option<String>,
    pub wait_after: Option<String>,
    pub wait_before: Option<String>,
    pub include_waiting: Option<bool>,
    pub include_scheduled: Option<bool>,
    pub include_blocked: Option<bool>,
    pub sort: Option<String>,
}

#[derive(Debug, Serialize)]
struct SavedViewListResponse {
    views: Vec<HttpSavedView>,
}

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
pub struct HttpDashboardLayout {
    pub id: String,
    pub name: String,
    pub enabled_widgets: Vec<String>,
    pub saved_view_widgets: Vec<HttpDashboardSavedViewWidget>,
    pub updated_at: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
pub struct HttpDashboardSavedViewWidget {
    pub id: String,
    pub title: String,
    pub view_id: String,
    pub filter: HttpSavedViewFilter,
}

#[derive(Debug, Serialize)]
struct DashboardLayoutListResponse {
    layouts: Vec<HttpDashboardLayout>,
}

#[derive(Default, Deserialize, Serialize)]
struct PersistedUiState {
    saved_views: BTreeMap<String, HttpSavedView>,
    dashboard_layouts: BTreeMap<String, HttpDashboardLayout>,
}

struct LoadedUiState {
    saved_views: BTreeMap<String, HttpSavedView>,
    dashboard_layouts: BTreeMap<String, HttpDashboardLayout>,
    path: Option<PathBuf>,
}

#[derive(Debug, Serialize)]
struct ApiErrorBody {
    error: String,
}

pub fn build_router() -> Router {
    build_router_with_state(AppState::default())
}

pub fn build_router_with_state(state: AppState) -> Router {
    Router::new()
        .route("/health", get(get_health))
        .route("/tasks", post(create_task))
        .route(
            "/tasks/{id}",
            get(get_task).patch(update_task),
        )
        .route(
            "/tasks/{id}/transition",
            post(transition_task),
        )
        .route(
            "/tasks/{id}/board-transition",
            post(transition_board_lane),
        )
        .route("/tasks/query", post(query_tasks))
        .route("/sync/status", get(get_sync_status))
        .route("/sync/retry", post(retry_sync))
        .route("/views", get(list_saved_views))
        .route(
            "/views/{id}",
            put(save_saved_view).delete(delete_saved_view),
        )
        .route(
            "/dashboard-layouts",
            get(list_dashboard_layouts),
        )
        .route(
            "/dashboard-layouts/{id}",
            put(save_dashboard_layout).delete(delete_dashboard_layout),
        )
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(state)
}

pub async fn start_server(address: SocketAddr) -> std::io::Result<()> {
    let listener = TcpListener::bind(address).await?;
    axum::serve(listener, build_router()).await
}

pub async fn start_server_with_config(
    address: SocketAddr,
    config: BackendConfig,
) -> std::io::Result<()> {
    let listener = TcpListener::bind(address).await?;
    let state = AppState::from_config(config)
        .await
        .map_err(|error| std::io::Error::other(format!("{error:?}")))?;
    axum::serve(listener, build_router_with_state(state)).await?;

    Ok(())
}

async fn get_health() -> Json<HealthResponse> {
    let _ = api_spec();

    Json(HealthResponse {
        status: healthcheck(),
    })
}

async fn create_task(
    State(state): State<AppState>,
    Json(request): Json<HttpCreateTaskRequest>,
) -> Result<Json<TaskResponse>, ServiceHttpError> {
    let mut service = state.service.lock().await;
    let task = service
        .create_task(CreateTaskRequest {
            id: Uuid::new_v4(),
            description: request.description,
            created_at: Utc::now(),
        })
        .await
        .map_err(ServiceHttpError)?;
    drop(service);
    sync_configured_storage(&state).await?;

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn get_task(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
) -> Result<Json<TaskResponse>, ServiceHttpError> {
    let task_id = parse_uuid(&task_id)?;
    sync_configured_storage(&state).await?;
    let mut service = state.service.lock().await;
    let task = service
        .get_task(task_id)
        .await
        .map_err(ServiceHttpError)?;

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn update_task(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
    Json(request): Json<HttpUpdateTaskRequest>,
) -> Result<Json<TaskResponse>, ServiceHttpError> {
    let task_id = parse_uuid(&task_id)?;
    let request = UpdateTaskRequest {
        description: request.description,
        project: request.project,
        clear_project: request.clear_project.unwrap_or(false),
        tags: request.tags,
        due: parse_optional_datetime(request.due)?,
        clear_due: request.clear_due.unwrap_or(false),
        scheduled: parse_optional_datetime(request.scheduled)?,
        clear_scheduled: request.clear_scheduled.unwrap_or(false),
        wait: parse_optional_datetime(request.wait)?,
        clear_wait: request.clear_wait.unwrap_or(false),
        recurrence: parse_recurrence(request.recurrence)?,
        clear_recurrence: request.clear_recurrence.unwrap_or(false),
        add_annotation: request.add_annotation,
        modified_at: parse_datetime_or_now(request.modified_at)?,
    };
    let mut service = state.service.lock().await;
    let task = service
        .update_task(task_id, request)
        .await
        .map_err(ServiceHttpError)?;
    drop(service);
    sync_configured_storage(&state).await?;

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn transition_board_lane(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
    Json(request): Json<HttpBoardTransitionRequest>,
) -> Result<Json<TaskResponse>, ServiceHttpError> {
    let task_id = parse_uuid(&task_id)?;
    let request = BoardTransitionRequest {
        lane: parse_board_lane(&request.lane),
        wait_until: parse_optional_datetime(request.wait_until)?,
        changed_at: parse_datetime_or_now(request.changed_at)?,
    };
    let mut service = state.service.lock().await;
    let task = service
        .transition_board_lane(task_id, request)
        .await
        .map_err(ServiceHttpError)?;
    drop(service);
    sync_configured_storage(&state).await?;

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn transition_task(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
    Json(request): Json<HttpTransitionTaskRequest>,
) -> Result<Json<TaskResponse>, ServiceHttpError> {
    let task_id = parse_uuid(&task_id)?;
    let mut service = state.service.lock().await;
    let task = service
        .transition_task(
            task_id,
            TransitionTaskRequest {
                status: parse_status(&request.status),
                changed_at: parse_datetime_or_now(request.changed_at)?,
            },
        )
        .await
        .map_err(ServiceHttpError)?;
    drop(service);
    sync_configured_storage(&state).await?;

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn query_tasks(
    State(state): State<AppState>,
    Json(request): Json<HttpTaskQueryRequest>,
) -> Result<Json<TaskListResponse>, ServiceHttpError> {
    let reference_time = parse_datetime_or_now(request.reference_time.clone())?;
    sync_configured_storage(&state).await?;
    let mut service = state.service.lock().await;
    let tasks = service
        .query_tasks(&build_task_query(
            request,
            reference_time,
        )?)
        .await
        .map_err(ServiceHttpError)?;

    Ok(Json(TaskListResponse {
        tasks: tasks.into_iter().map(map_task).collect(),
    }))
}

async fn get_sync_status(
    State(state): State<AppState>
) -> Json<SyncStatusResponse> {
    Json(state.sync_status.lock().await.response())
}

async fn retry_sync(State(state): State<AppState>) -> Json<SyncStatusResponse> {
    let _ = sync_configured_storage(&state).await;

    Json(state.sync_status.lock().await.response())
}

async fn sync_configured_storage(
    state: &AppState
) -> Result<(), ServiceHttpError> {
    if !state.sync_config.is_enabled() {
        return Ok(());
    }

    let mut status = state.sync_status.lock().await;
    *status = status.syncing();
    drop(status);

    let storage = state.storage_config.clone();
    let sync = state.sync_config.clone();
    let result = tokio::task::spawn_blocking(move || {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(sync_io_error)?;
        runtime.block_on(async move {
            let mut store = TaskChampionTaskStore::from_config(storage)
                .await
                .map_err(sync_compat_error)?;
            store
                .sync(sync)
                .await
                .map_err(sync_compat_error)?;
            Ok::<(), ServiceHttpError>(())
        })
    })
    .await
    .map_err(sync_join_error)
    .and_then(|result| result);

    if let Err(error) = result {
        record_sync_failure(state, &error).await;
        return Err(error);
    }

    let repository = match TaskChampionTaskRepository::from_storage_config(
        state.storage_config.clone(),
    )
    .await
    .map_err(sync_compat_error)
    {
        Ok(repository) => repository,
        Err(error) => {
            record_sync_failure(state, &error).await;
            return Err(error);
        }
    };
    let sync = InMemorySyncCoordinator::configured(state.sync_config.clone());
    let mut service = state.service.lock().await;
    *service = TaskService::new(repository, sync);
    *state.sync_status.lock().await = HttpSyncState::succeeded(Utc::now());

    Ok(())
}

async fn record_sync_failure(
    state: &AppState,
    error: &ServiceHttpError,
) {
    let summary = product_safe_sync_error(error);
    *state.sync_status.lock().await =
        HttpSyncState::failed(Utc::now(), summary);
}

fn product_safe_sync_error(error: &ServiceHttpError) -> String {
    match &error.0 {
        ServiceError::Sync(_) => {
            "Task synchronization failed. Check backend sync configuration."
                .to_string()
        }
        ServiceError::Compatibility(_) => {
            "Task synchronization failed. Check sync server availability."
                .to_string()
        }
        ServiceError::Validation(_) => "Sync request was invalid.".to_string(),
        ServiceError::NotFound(_) => "Sync target was not found.".to_string(),
    }
}

async fn list_saved_views(
    State(state): State<AppState>
) -> Json<SavedViewListResponse> {
    let views = state.saved_views.lock().await;

    Json(SavedViewListResponse {
        views: views.values().cloned().collect(),
    })
}

async fn save_saved_view(
    State(state): State<AppState>,
    Path(view_id): Path<String>,
    Json(view): Json<HttpSavedView>,
) -> Result<Json<HttpSavedView>, ServiceHttpError> {
    validate_saved_view(&view_id, &view)?;
    {
        let mut views = state.saved_views.lock().await;
        views.insert(view_id, view.clone());
    }
    persist_ui_state(&state).await?;

    Ok(Json(view))
}

async fn delete_saved_view(
    State(state): State<AppState>,
    Path(view_id): Path<String>,
) -> Result<StatusCode, ServiceHttpError> {
    {
        let mut views = state.saved_views.lock().await;
        views.remove(&view_id);
    }
    persist_ui_state(&state).await?;

    Ok(StatusCode::NO_CONTENT)
}

async fn list_dashboard_layouts(
    State(state): State<AppState>
) -> Json<DashboardLayoutListResponse> {
    let layouts = state.dashboard_layouts.lock().await;

    Json(DashboardLayoutListResponse {
        layouts: layouts.values().cloned().collect(),
    })
}

async fn save_dashboard_layout(
    State(state): State<AppState>,
    Path(layout_id): Path<String>,
    Json(layout): Json<HttpDashboardLayout>,
) -> Result<Json<HttpDashboardLayout>, ServiceHttpError> {
    validate_dashboard_layout(&layout_id, &layout)?;
    {
        let mut layouts = state.dashboard_layouts.lock().await;
        layouts.insert(layout_id, layout.clone());
    }
    persist_ui_state(&state).await?;

    Ok(Json(layout))
}

async fn delete_dashboard_layout(
    State(state): State<AppState>,
    Path(layout_id): Path<String>,
) -> Result<StatusCode, ServiceHttpError> {
    {
        let mut layouts = state.dashboard_layouts.lock().await;
        layouts.remove(&layout_id);
    }
    persist_ui_state(&state).await?;

    Ok(StatusCode::NO_CONTENT)
}

fn load_ui_state(
    config: &UiStateConfig
) -> Result<LoadedUiState, ServiceError> {
    match config {
        UiStateConfig::InMemory => Ok(LoadedUiState {
            saved_views: BTreeMap::new(),
            dashboard_layouts: BTreeMap::new(),
            path: None,
        }),
        UiStateConfig::JsonFile(path) => {
            if !path.exists() {
                return Ok(LoadedUiState {
                    saved_views: BTreeMap::new(),
                    dashboard_layouts: BTreeMap::new(),
                    path: Some(path.clone()),
                });
            }

            let raw = fs::read_to_string(path).map_err(ui_state_error)?;
            let persisted: PersistedUiState =
                serde_json::from_str(&raw).map_err(ui_state_error)?;

            Ok(LoadedUiState {
                saved_views: persisted.saved_views,
                dashboard_layouts: persisted.dashboard_layouts,
                path: Some(path.clone()),
            })
        }
    }
}

async fn persist_ui_state(state: &AppState) -> Result<(), ServiceHttpError> {
    let Some(path) = &state.ui_state_path else {
        return Ok(());
    };
    let saved_views = state.saved_views.lock().await.clone();
    let dashboard_layouts = state.dashboard_layouts.lock().await.clone();
    let persisted = PersistedUiState {
        saved_views,
        dashboard_layouts,
    };
    if let Some(parent) = path
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
    {
        fs::create_dir_all(parent).map_err(ui_state_http_error)?;
    }
    let raw = serde_json::to_string_pretty(&persisted)
        .map_err(ui_state_http_error)?;
    fs::write(path.as_ref(), raw).map_err(ui_state_http_error)?;

    Ok(())
}

fn ui_state_error(error: impl std::fmt::Display) -> ServiceError {
    ServiceError::Sync(format!(
        "ui state persistence failed: {error}"
    ))
}

fn ui_state_http_error(error: impl std::fmt::Display) -> ServiceHttpError {
    ServiceHttpError(ui_state_error(error))
}

fn sync_io_error(error: impl std::fmt::Display) -> ServiceHttpError {
    ServiceHttpError(ServiceError::Sync(format!(
        "taskchampion sync runtime failed: {error}"
    )))
}

fn sync_compat_error(error: impl std::fmt::Display) -> ServiceHttpError {
    ServiceHttpError(ServiceError::Sync(format!(
        "taskchampion sync failed: {error}"
    )))
}

fn sync_join_error(error: impl std::fmt::Display) -> ServiceHttpError {
    ServiceHttpError(ServiceError::Sync(format!(
        "taskchampion sync task failed: {error}"
    )))
}

fn build_task_query(
    request: HttpTaskQueryRequest,
    reference_time: DateTime<Utc>,
) -> Result<TaskQuery, ServiceHttpError> {
    if parse_query_preset(request.preset.as_deref()) != TaskQueryPreset::Custom
    {
        return Ok(
            match parse_query_preset(request.preset.as_deref()) {
                TaskQueryPreset::Inbox => TaskQuery::inbox(reference_time),
                TaskQueryPreset::NextActions => {
                    TaskQuery::next_actions(reference_time)
                }
                TaskQueryPreset::Waiting => TaskQuery::waiting(reference_time),
                TaskQueryPreset::Review => TaskQuery::review(reference_time),
                TaskQueryPreset::Custom => TaskQuery::all(reference_time),
            },
        );
    }

    Ok(TaskQuery {
        preset: TaskQueryPreset::Custom,
        statuses: request
            .statuses
            .unwrap_or_default()
            .into_iter()
            .map(|status| parse_status(&status))
            .collect(),
        project: request.project,
        no_project: request.no_project.unwrap_or(false),
        required_tag: request.required_tag,
        no_tags: request.no_tags.unwrap_or(false),
        due_after: parse_optional_datetime(request.due_after)?,
        due_before: parse_optional_datetime(request.due_before)?,
        scheduled_after: parse_optional_datetime(request.scheduled_after)?,
        scheduled_before: parse_optional_datetime(request.scheduled_before)?,
        wait_after: parse_optional_datetime(request.wait_after)?,
        wait_before: parse_optional_datetime(request.wait_before)?,
        include_waiting: request.include_waiting.unwrap_or(true),
        include_scheduled: request.include_scheduled.unwrap_or(true),
        include_blocked: request.include_blocked.unwrap_or(true),
        reference_time,
        sort: parse_sort(request.sort.as_deref()),
    })
}

fn validate_saved_view(
    expected_id: &str,
    view: &HttpSavedView,
) -> Result<(), ServiceHttpError> {
    if view.id != expected_id {
        return Err(ServiceHttpError(ServiceError::Sync(
            "view id does not match request path".to_string(),
        )));
    }

    if view.id.trim().is_empty() || view.name.trim().is_empty() {
        return Err(ServiceHttpError(ServiceError::Sync(
            "view id and name are required".to_string(),
        )));
    }

    let query = HttpTaskQueryRequest {
        preset: view.filter.preset.clone(),
        statuses: view.filter.statuses.clone(),
        project: view.filter.project.clone(),
        no_project: view.filter.no_project,
        required_tag: view.filter.required_tag.clone(),
        no_tags: view.filter.no_tags,
        due_after: view.filter.due_after.clone(),
        due_before: view.filter.due_before.clone(),
        scheduled_after: view.filter.scheduled_after.clone(),
        scheduled_before: view.filter.scheduled_before.clone(),
        wait_after: view.filter.wait_after.clone(),
        wait_before: view.filter.wait_before.clone(),
        include_waiting: view.filter.include_waiting,
        include_scheduled: view.filter.include_scheduled,
        include_blocked: view.filter.include_blocked,
        reference_time: None,
        sort: view.filter.sort.clone(),
    };
    build_task_query(query, Utc::now())?
        .validate()
        .map_err(|error| ServiceHttpError(ServiceError::Validation(error)))?;
    parse_datetime(view.updated_at.clone())?;

    Ok(())
}

fn validate_dashboard_layout(
    expected_id: &str,
    layout: &HttpDashboardLayout,
) -> Result<(), ServiceHttpError> {
    if layout.id != expected_id {
        return Err(ServiceHttpError(ServiceError::Sync(
            "dashboard layout id does not match request path".to_string(),
        )));
    }

    if layout.id.trim().is_empty() || layout.name.trim().is_empty() {
        return Err(ServiceHttpError(ServiceError::Sync(
            "dashboard layout id and name are required".to_string(),
        )));
    }

    for widget in &layout.saved_view_widgets {
        validate_dashboard_saved_view_widget(widget)?;
    }
    parse_datetime(layout.updated_at.clone())?;

    Ok(())
}

fn validate_dashboard_saved_view_widget(
    widget: &HttpDashboardSavedViewWidget
) -> Result<(), ServiceHttpError> {
    if widget.id.trim().is_empty()
        || widget.title.trim().is_empty()
        || widget.view_id.trim().is_empty()
    {
        return Err(ServiceHttpError(ServiceError::Sync(
            "dashboard saved view widget fields are required".to_string(),
        )));
    }

    let query = HttpTaskQueryRequest {
        preset: widget.filter.preset.clone(),
        statuses: widget.filter.statuses.clone(),
        project: widget.filter.project.clone(),
        no_project: widget.filter.no_project,
        required_tag: widget.filter.required_tag.clone(),
        no_tags: widget.filter.no_tags,
        due_after: widget.filter.due_after.clone(),
        due_before: widget.filter.due_before.clone(),
        scheduled_after: widget.filter.scheduled_after.clone(),
        scheduled_before: widget.filter.scheduled_before.clone(),
        wait_after: widget.filter.wait_after.clone(),
        wait_before: widget.filter.wait_before.clone(),
        include_waiting: widget.filter.include_waiting,
        include_scheduled: widget.filter.include_scheduled,
        include_blocked: widget.filter.include_blocked,
        reference_time: None,
        sort: widget.filter.sort.clone(),
    };
    build_task_query(query, Utc::now())?
        .validate()
        .map_err(|error| ServiceHttpError(ServiceError::Validation(error)))?;

    Ok(())
}

fn parse_query_preset(raw: Option<&str>) -> TaskQueryPreset {
    match raw.unwrap_or("custom") {
        "inbox" => TaskQueryPreset::Inbox,
        "next_actions" => TaskQueryPreset::NextActions,
        "waiting" => TaskQueryPreset::Waiting,
        "review" => TaskQueryPreset::Review,
        _ => TaskQueryPreset::Custom,
    }
}

fn parse_board_lane(raw: &str) -> BoardLaneTransition {
    match raw {
        "pending" => BoardLaneTransition::Pending,
        "recurring" => BoardLaneTransition::Recurring,
        "waiting" => BoardLaneTransition::Waiting,
        "completed" => BoardLaneTransition::Completed,
        _ => BoardLaneTransition::Pending,
    }
}

fn parse_recurrence(
    raw: Option<HttpRecurrence>
) -> Result<Option<taskwarrior_core::TaskRecurrence>, ServiceHttpError> {
    raw.map(|recurrence| {
        let mut parsed =
            taskwarrior_core::TaskRecurrence::new(recurrence.recur);
        parsed.rtype = recurrence.rtype;
        parsed.until = parse_optional_datetime(recurrence.until)?;
        parsed.parent = recurrence
            .parent
            .map(|parent| parse_uuid(&parent))
            .transpose()?;
        parsed.mask = recurrence.mask;
        parsed.imask = recurrence.imask;

        Ok(parsed)
    })
    .transpose()
}

fn parse_uuid(raw: &str) -> Result<Uuid, ServiceHttpError> {
    Uuid::parse_str(raw).map_err(|_| {
        ServiceHttpError(ServiceError::Sync(
            "invalid uuid".to_string(),
        ))
    })
}

fn parse_sort(raw: Option<&str>) -> TaskSort {
    match raw.unwrap_or("due_asc") {
        "modified_desc" => TaskSort::ModifiedDesc,
        "description_asc" => TaskSort::DescriptionAsc,
        _ => TaskSort::DueAsc,
    }
}

fn parse_optional_datetime(
    raw: Option<String>
) -> Result<Option<DateTime<Utc>>, ServiceHttpError> {
    raw.map(parse_datetime).transpose()
}

fn parse_datetime_or_now(
    raw: Option<String>
) -> Result<DateTime<Utc>, ServiceHttpError> {
    raw.map(parse_datetime)
        .transpose()
        .map(|value| value.unwrap_or_else(Utc::now))
}

fn parse_datetime(raw: String) -> Result<DateTime<Utc>, ServiceHttpError> {
    DateTime::parse_from_rfc3339(&raw)
        .map(|value| value.with_timezone(&Utc))
        .map_err(|_| {
            ServiceHttpError(ServiceError::Sync(
                "invalid timestamp".to_string(),
            ))
        })
}

struct ServiceHttpError(ServiceError);

impl IntoResponse for ServiceHttpError {
    fn into_response(self) -> Response {
        let (status, message) = match self.0 {
            ServiceError::Validation(error) => (
                StatusCode::BAD_REQUEST,
                format!("{error:?}"),
            ),
            ServiceError::NotFound(_) => (
                StatusCode::NOT_FOUND,
                "task not found".to_string(),
            ),
            ServiceError::Compatibility(error) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                error.to_string(),
            ),
            ServiceError::Sync(message) => (StatusCode::BAD_REQUEST, message),
        };

        (
            status,
            Json(ApiErrorBody { error: message }),
        )
            .into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::{build_router, AppState, HttpCreateTaskRequest};
    use crate::config::{BackendConfig, UiStateConfig};
    use axum::body::Body;
    use axum::http::{Method, Request, StatusCode};
    use serde_json::{json, Value};
    use std::path::PathBuf;
    use taskwarrior_compat::{
        TaskChampionLocalSyncConfig, TaskChampionRemoteSyncConfig,
        TaskChampionStorageConfig, TaskChampionSyncConfig,
    };
    use tower::ServiceExt;
    use uuid::Uuid;

    #[tokio::test]
    async fn http_routes_support_create_update_complete_and_query() {
        let app = build_router();

        let create = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/tasks")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&HttpCreateTaskRequest {
                            description: "Milestone 4".to_string(),
                        })
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(create.status(), StatusCode::OK);
        let body = axum::body::to_bytes(create.into_body(), usize::MAX)
            .await
            .unwrap();
        let created: Value = serde_json::from_slice(&body).unwrap();
        let task_id = created["task"]["id"]
            .as_str()
            .unwrap()
            .to_string();

        let update = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!("/tasks/{task_id}"))
                    .header("content-type", "application/json")
                    .body(Body::from(
                        json!({
                            "description": "Milestone 4 updated",
                            "project": "frontend",
                            "tags": ["home", "next"],
                            "due": "1970-01-01T00:01:00Z",
                            "add_annotation": "ready to complete",
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(update.status(), StatusCode::OK);

        let transition = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/tasks/{task_id}/transition"))
                    .header("content-type", "application/json")
                    .body(Body::from(
                        json!({"status": "completed"}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(transition.status(), StatusCode::OK);

        let query = app
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/tasks/query")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        json!({
                            "statuses": ["completed"],
                            "required_tag": "home",
                            "due_after": "1970-01-01T00:00:00Z",
                            "due_before": "1970-01-01T00:05:00Z",
                            "sort": "modified_desc",
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(query.status(), StatusCode::OK);
        let body = axum::body::to_bytes(query.into_body(), usize::MAX)
            .await
            .unwrap();
        let queried: Value = serde_json::from_slice(&body).unwrap();

        assert_eq!(
            queried["tasks"].as_array().unwrap().len(),
            1
        );
        assert_eq!(
            queried["tasks"][0]["description"],
            "Milestone 4 updated",
        );
        assert_eq!(
            queried["tasks"][0]["project"],
            "frontend"
        );
    }

    #[tokio::test]
    async fn http_query_supports_next_actions_preset() {
        let app = build_router();

        let ready = create_http_task(&app, "Ready action").await;
        let waiting = create_http_task(&app, "Waiting action").await;
        let wait_until = "2026-04-12T12:00:00Z";

        let update = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!("/tasks/{waiting}"))
                    .header("content-type", "application/json")
                    .body(Body::from(
                        json!({"wait": wait_until}).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(update.status(), StatusCode::OK);

        let query = app
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/tasks/query")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        json!({
                            "preset": "next_actions",
                            "reference_time": "2026-04-12T10:00:00Z",
                        })
                        .to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(query.status(), StatusCode::OK);
        let body = axum::body::to_bytes(query.into_body(), usize::MAX)
            .await
            .unwrap();
        let queried: Value = serde_json::from_slice(&body).unwrap();

        assert_eq!(
            queried["tasks"].as_array().unwrap().len(),
            1
        );
        assert_eq!(queried["tasks"][0]["id"], ready);
    }

    #[tokio::test]
    async fn http_routes_support_shared_saved_views() {
        let app = build_router();
        let saved_view = json!({
            "id": "ready-next",
            "name": "Ready next",
            "updated_at": "2026-04-12T10:00:00Z",
            "filter": {
                "preset": "custom",
                "statuses": ["pending"],
                "required_tag": "next",
                "no_project": false,
                "no_tags": false,
                "include_waiting": false,
                "include_scheduled": false,
                "include_blocked": false,
                "sort": "due_asc"
            }
        });

        let save = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PUT)
                    .uri("/views/ready-next")
                    .header("content-type", "application/json")
                    .body(Body::from(saved_view.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(save.status(), StatusCode::OK);

        let list = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::GET)
                    .uri("/views")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(list.status(), StatusCode::OK);
        let body = axum::body::to_bytes(list.into_body(), usize::MAX)
            .await
            .unwrap();
        let listed: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            listed["views"].as_array().unwrap().len(),
            1
        );
        assert_eq!(listed["views"][0]["name"], "Ready next");

        let delete = app
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri("/views/ready-next")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(delete.status(), StatusCode::NO_CONTENT);
    }

    #[tokio::test]
    async fn http_routes_support_shared_dashboard_layouts() {
        let app = build_router();
        let layout = json!({
            "id": "daily-layout",
            "name": "Daily layout",
            "enabled_widgets": ["readyNow"],
            "updated_at": "2026-04-12T10:00:00Z",
            "saved_view_widgets": [{
                "id": "dashboard-widget-1",
                "title": "Frontend work",
                "view_id": "frontend-work",
                "filter": {
                    "preset": "custom",
                    "statuses": ["pending"],
                    "project": "Flutter",
                    "no_project": false,
                    "no_tags": false,
                    "include_waiting": true,
                    "include_scheduled": true,
                    "include_blocked": true,
                    "sort": "due_asc"
                }
            }]
        });

        let save = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PUT)
                    .uri("/dashboard-layouts/daily-layout")
                    .header("content-type", "application/json")
                    .body(Body::from(layout.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(save.status(), StatusCode::OK);

        let list = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::GET)
                    .uri("/dashboard-layouts")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(list.status(), StatusCode::OK);
        let body = axum::body::to_bytes(list.into_body(), usize::MAX)
            .await
            .unwrap();
        let listed: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            listed["layouts"].as_array().unwrap().len(),
            1
        );
        assert_eq!(
            listed["layouts"][0]["name"],
            "Daily layout"
        );

        let delete = app
            .oneshot(
                Request::builder()
                    .method(Method::DELETE)
                    .uri("/dashboard-layouts/daily-layout")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(delete.status(), StatusCode::NO_CONTENT);
    }

    #[tokio::test]
    async fn http_shared_configuration_persists_across_restart() {
        let path = temp_ui_state_path();
        let first_state = AppState::from_config(BackendConfig {
            ui_state: UiStateConfig::JsonFile(path.clone()),
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let first = super::build_router_with_state(first_state);
        let saved_view = json!({
            "id": "ready-next",
            "name": "Ready next",
            "updated_at": "2026-04-12T10:00:00Z",
            "filter": {
                "preset": "custom",
                "statuses": ["pending"],
                "no_project": false,
                "no_tags": false,
                "include_waiting": false,
                "include_scheduled": false,
                "include_blocked": false,
                "sort": "due_asc"
            }
        });
        let layout = json!({
            "id": "daily-layout",
            "name": "Daily layout",
            "enabled_widgets": ["readyNow"],
            "updated_at": "2026-04-12T10:00:00Z",
            "saved_view_widgets": [{
                "id": "dashboard-widget-1",
                "title": "Ready next",
                "view_id": "ready-next",
                "filter": saved_view["filter"]
            }]
        });

        put_json(&first, "/views/ready-next", saved_view).await;
        put_json(
            &first,
            "/dashboard-layouts/daily-layout",
            layout,
        )
        .await;

        let second_state = AppState::from_config(BackendConfig {
            ui_state: UiStateConfig::JsonFile(path.clone()),
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let second = super::build_router_with_state(second_state);
        let listed_views = get_json(&second, "/views").await;
        let listed_layouts = get_json(&second, "/dashboard-layouts").await;

        assert_eq!(
            listed_views["views"][0]["name"],
            "Ready next"
        );
        assert_eq!(
            listed_layouts["layouts"][0]["name"],
            "Daily layout"
        );

        let _ = std::fs::remove_file(path);
    }

    #[tokio::test]
    async fn http_task_writes_sync_and_reads_pull_from_taskchampion_server() {
        let server_dir = temp_sync_server_path();
        std::fs::create_dir_all(&server_dir).unwrap();
        let sync = TaskChampionSyncConfig::Local(TaskChampionLocalSyncConfig {
            server_dir: server_dir.clone(),
        });
        let first_storage = temp_sqlite_path();
        let second_storage = temp_sqlite_path();
        let first_state = AppState::from_config(BackendConfig {
            storage: TaskChampionStorageConfig::Sqlite {
                path: first_storage.clone(),
                create_if_missing: true,
            },
            sync: sync.clone(),
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let first = super::build_router_with_state(first_state);
        let second_state = AppState::from_config(BackendConfig {
            storage: TaskChampionStorageConfig::Sqlite {
                path: second_storage.clone(),
                create_if_missing: true,
            },
            sync,
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let second = super::build_router_with_state(second_state);

        let created = create_http_task(&first, "Synced through HTTP").await;
        let queried = post_json(
            &second,
            "/tasks/query",
            json!({
                "statuses": ["pending"],
                "reference_time": "2026-04-12T10:00:00Z"
            }),
        )
        .await;

        assert_eq!(queried["tasks"][0]["id"], created);
        assert_eq!(
            queried["tasks"][0]["description"],
            "Synced through HTTP"
        );

        let _ = std::fs::remove_dir_all(server_dir);
        let _ = std::fs::remove_file(first_storage);
        let _ = std::fs::remove_file(second_storage);
    }

    #[tokio::test]
    async fn sync_status_reports_disabled_state() {
        let app = build_router();
        let status = get_json(&app, "/sync/status").await;

        assert_eq!(status["state"], "disabled");
        assert_eq!(status["retry_available"], false);
        assert_eq!(status["last_attempt_at"], Value::Null);
        assert_eq!(status["error_summary"], Value::Null);
    }

    #[tokio::test]
    async fn sync_retry_reports_invalid_sync_config_without_credentials() {
        let state = AppState::from_config(BackendConfig {
            sync: TaskChampionSyncConfig::Remote(
                TaskChampionRemoteSyncConfig {
                    url: "http://127.0.0.1:1".to_string(),
                    client_id: Uuid::new_v4(),
                    encryption_secret: b"secret".to_vec(),
                    allow_plain_http: false,
                },
            ),
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let app = super::build_router_with_state(state);

        let status = post_json(&app, "/sync/retry", json!({})).await;

        assert_eq!(status["state"], "failed");
        assert_eq!(status["retry_available"], true);
        assert!(status["last_attempt_at"].is_string());
        assert_eq!(
            status["error_summary"],
            "Task synchronization failed. Check backend sync configuration."
        );
        assert!(!status["error_summary"]
            .as_str()
            .unwrap()
            .contains("secret"));
    }

    #[tokio::test]
    async fn sync_retry_reports_unavailable_sync_server() {
        let state = AppState::from_config(BackendConfig {
            sync: TaskChampionSyncConfig::Remote(
                TaskChampionRemoteSyncConfig {
                    url: "http://127.0.0.1:9".to_string(),
                    client_id: Uuid::new_v4(),
                    encryption_secret: b"secret".to_vec(),
                    allow_plain_http: true,
                },
            ),
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let app = super::build_router_with_state(state);

        let status = post_json(&app, "/sync/retry", json!({})).await;

        assert_eq!(status["state"], "failed");
        assert_eq!(status["retry_available"], true);
        assert!(status["error_summary"].as_str().unwrap().len() > 3);
    }

    #[tokio::test]
    async fn sync_retry_recovers_after_local_server_becomes_available() {
        let server_dir = temp_sync_server_path();
        let state = AppState::from_config(BackendConfig {
            sync: TaskChampionSyncConfig::Local(TaskChampionLocalSyncConfig {
                server_dir: server_dir.clone(),
            }),
            ..BackendConfig::default()
        })
        .await
        .unwrap();
        let app = super::build_router_with_state(state);

        let failed = post_json(&app, "/sync/retry", json!({})).await;
        assert_eq!(failed["state"], "failed");

        std::fs::create_dir_all(&server_dir).unwrap();
        let recovered = post_json(&app, "/sync/retry", json!({})).await;

        assert_eq!(recovered["state"], "succeeded");
        assert_eq!(recovered["retry_available"], true);
        assert_eq!(recovered["error_summary"], Value::Null);
        assert!(recovered["last_attempt_at"].is_string());

        let _ = std::fs::remove_dir_all(server_dir);
    }

    async fn create_http_task(
        app: &axum::Router,
        description: &str,
    ) -> String {
        let response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/tasks")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        json!({ "description": description }).to_string(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        let status = response.status();
        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&body)
        );
        let created: Value = serde_json::from_slice(&body).unwrap();

        created["task"]["id"]
            .as_str()
            .unwrap()
            .to_string()
    }

    async fn put_json(
        app: &axum::Router,
        path: &str,
        body: Value,
    ) {
        let response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PUT)
                    .uri(path)
                    .header("content-type", "application/json")
                    .body(Body::from(body.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
    }

    async fn post_json(
        app: &axum::Router,
        path: &str,
        body: Value,
    ) -> Value {
        let response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(path)
                    .header("content-type", "application/json")
                    .body(Body::from(body.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();

        serde_json::from_slice(&body).unwrap()
    }

    async fn get_json(
        app: &axum::Router,
        path: &str,
    ) -> Value {
        let response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::GET)
                    .uri(path)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();

        serde_json::from_slice(&body).unwrap()
    }

    fn temp_ui_state_path() -> PathBuf {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();

        std::env::temp_dir().join(format!(
            "taskwarrior-frontend-ui-state-{}.json",
            now
        ))
    }

    fn temp_sqlite_path() -> PathBuf {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();

        std::env::temp_dir().join(format!(
            "taskwarrior-frontend-http-sync-{now}.sqlite"
        ))
    }

    fn temp_sync_server_path() -> PathBuf {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();

        std::env::temp_dir().join(format!(
            "taskwarrior-frontend-http-sync-{now}"
        ))
    }
}
