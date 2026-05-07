use crate::config::BackendConfig;
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
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::Mutex;
use tower_http::cors::{Any, CorsLayer};
use uuid::Uuid;

type AppService =
    TaskService<TaskChampionTaskRepository, InMemorySyncCoordinator>;

#[derive(Clone)]
pub struct AppState {
    service: Arc<Mutex<AppService>>,
    saved_views: Arc<Mutex<BTreeMap<String, HttpSavedView>>>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            service: Arc::new(Mutex::new(TaskService::new(
                TaskChampionTaskRepository::default(),
                InMemorySyncCoordinator::disabled(),
            ))),
            saved_views: Arc::new(Mutex::new(BTreeMap::new())),
        }
    }
}

impl AppState {
    pub async fn from_config(
        config: BackendConfig
    ) -> Result<Self, ServiceError> {
        let repository =
            TaskChampionTaskRepository::from_storage_config(config.storage)
                .await?;
        let sync = if config.sync.is_enabled() {
            InMemorySyncCoordinator::configured(config.sync)
        } else {
            InMemorySyncCoordinator::disabled()
        };

        Ok(Self {
            service: Arc::new(Mutex::new(TaskService::new(
                repository, sync,
            ))),
            saved_views: Arc::new(Mutex::new(BTreeMap::new())),
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
        .route("/views", get(list_saved_views))
        .route(
            "/views/{id}",
            put(save_saved_view).delete(delete_saved_view),
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

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn get_task(
    State(state): State<AppState>,
    Path(task_id): Path<String>,
) -> Result<Json<TaskResponse>, ServiceHttpError> {
    let task_id = parse_uuid(&task_id)?;
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

    Ok(Json(TaskResponse {
        task: map_task(task),
    }))
}

async fn query_tasks(
    State(state): State<AppState>,
    Json(request): Json<HttpTaskQueryRequest>,
) -> Result<Json<TaskListResponse>, ServiceHttpError> {
    let reference_time = parse_datetime_or_now(request.reference_time.clone())?;
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
    let mut views = state.saved_views.lock().await;
    views.insert(view_id, view.clone());

    Ok(Json(view))
}

async fn delete_saved_view(
    State(state): State<AppState>,
    Path(view_id): Path<String>,
) -> StatusCode {
    let mut views = state.saved_views.lock().await;
    views.remove(&view_id);

    StatusCode::NO_CONTENT
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
    use super::{build_router, HttpCreateTaskRequest};
    use axum::body::Body;
    use axum::http::{Method, Request, StatusCode};
    use serde_json::{json, Value};
    use tower::ServiceExt;

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
        assert_eq!(response.status(), StatusCode::OK);
        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .unwrap();
        let created: Value = serde_json::from_slice(&body).unwrap();

        created["task"]["id"]
            .as_str()
            .unwrap()
            .to_string()
    }
}
