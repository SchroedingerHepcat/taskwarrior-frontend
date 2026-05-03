use crate::error::ServiceError;
use crate::operations::{
    api_spec, healthcheck, map_task, parse_status, HealthResponse,
    TaskListResponse, TaskResponse,
};
use crate::requests::{
    CreateTaskRequest, TaskQuery, TaskSort, TransitionTaskRequest,
    UpdateTaskRequest,
};
use crate::service::TaskService;
use crate::storage::TaskChampionTaskRepository;
use crate::sync::InMemorySyncCoordinator;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
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
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            service: Arc::new(Mutex::new(TaskService::new(
                TaskChampionTaskRepository::default(),
                InMemorySyncCoordinator::default(),
            ))),
        }
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
    pub wait: Option<String>,
    pub clear_wait: Option<bool>,
    pub add_annotation: Option<String>,
    pub modified_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HttpTransitionTaskRequest {
    pub status: String,
    pub changed_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HttpTaskQueryRequest {
    pub statuses: Option<Vec<String>>,
    pub required_tag: Option<String>,
    pub due_before: Option<String>,
    pub include_waiting: Option<bool>,
    pub reference_time: Option<String>,
    pub sort: Option<String>,
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
        .route("/tasks/query", post(query_tasks))
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
        wait: parse_optional_datetime(request.wait)?,
        clear_wait: request.clear_wait.unwrap_or(false),
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
    let reference_time = parse_datetime_or_now(request.reference_time)?;
    let mut service = state.service.lock().await;
    let tasks = service
        .query_tasks(&TaskQuery {
            statuses: request
                .statuses
                .unwrap_or_default()
                .into_iter()
                .map(|status| parse_status(&status))
                .collect(),
            required_tag: request.required_tag,
            due_before: parse_optional_datetime(request.due_before)?,
            include_waiting: request.include_waiting.unwrap_or(true),
            reference_time,
            sort: parse_sort(request.sort.as_deref()),
        })
        .await
        .map_err(ServiceHttpError)?;

    Ok(Json(TaskListResponse {
        tasks: tasks.into_iter().map(map_task).collect(),
    }))
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
}
