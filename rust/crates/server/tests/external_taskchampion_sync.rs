use axum::body::{to_bytes, Body};
use axum::http::{Request, StatusCode};
use serde_json::{json, Value};
use server::{AppState, BackendConfig};
use std::path::{Path, PathBuf};
use std::process::Command;
use taskwarrior_compat::{
    TaskChampionRemoteSyncConfig, TaskChampionStorageConfig,
    TaskChampionSyncConfig,
};
use testcontainers::{
    core::{IntoContainerPort, WaitFor},
    runners::AsyncRunner,
    GenericImage, ImageExt,
};
use tower::ServiceExt;
use uuid::Uuid;

#[tokio::test]
#[ignore = "requires Docker and taskwarrior CLI"]
async fn external_sync_round_trips_backend_and_taskwarrior() {
    let server = start_sync_server().await;
    let port = server
        .get_host_port_ipv4(8080.tcp())
        .await
        .unwrap();
    let url = format!("http://127.0.0.1:{port}");
    let client_id = Uuid::new_v4();
    let secret = format!("taskwarrior-frontend-sync-proof-{client_id}");
    let sync = TaskChampionSyncConfig::Remote(TaskChampionRemoteSyncConfig {
        url: url.clone(),
        client_id,
        encryption_secret: secret.as_bytes().to_vec(),
        allow_plain_http: true,
    });
    let backend_a_storage = temp_path("backend-a.sqlite");
    let backend_b_storage = temp_path("backend-b.sqlite");
    let taskwarrior_home = temp_path("taskwarrior");
    let taskwarrior_data = taskwarrior_home.join("data");
    let taskwarrior_rc = taskwarrior_home.join("taskrc");
    std::fs::create_dir_all(&taskwarrior_data).unwrap();
    std::fs::write(&taskwarrior_rc, "").unwrap();

    let backend_a = backend(sync.clone(), backend_a_storage.clone()).await;
    let backend_b = backend(sync, backend_b_storage.clone()).await;

    let created_id = create_http_task(&backend_a).await;
    update_http_task(&backend_a, &created_id).await;

    run_task_sync(
        &taskwarrior_rc,
        &taskwarrior_data,
        client_id,
        &secret,
        &url,
    );
    let taskwarrior_tasks = task_export(
        &taskwarrior_rc,
        &taskwarrior_data,
        client_id,
        &secret,
        &url,
    );
    let pulled = find_task(
        &taskwarrior_tasks,
        "Backend synced task",
    );
    assert_eq!(pulled["project"], "sync.proof");
    assert_has_tag(pulled, "backend");
    assert_eq!(pulled["recur"], "daily");
    assert_eq!(pulled["rtype"], "periodic");

    run_task_add(
        &taskwarrior_rc,
        &taskwarrior_data,
        client_id,
        &secret,
        &url,
    );
    run_task_sync(
        &taskwarrior_rc,
        &taskwarrior_data,
        client_id,
        &secret,
        &url,
    );
    let taskwarrior_after_add = task_export(
        &taskwarrior_rc,
        &taskwarrior_data,
        client_id,
        &secret,
        &url,
    );
    find_task(
        &taskwarrior_after_add,
        "Taskwarrior synced task",
    );

    let queried = query_http_tasks(&backend_b).await;
    let backend_created = find_task(&queried["tasks"], "Backend synced task");
    assert_eq!(backend_created["project"], "sync.proof");
    assert_has_tag(backend_created, "backend");
    assert_eq!(
        backend_created["recurrence"]["recur"],
        "daily"
    );
    assert_eq!(
        backend_created["recurrence"]["rtype"],
        "periodic"
    );

    let taskwarrior_created = find_task(
        &queried["tasks"],
        "Taskwarrior synced task",
    );
    assert_eq!(
        taskwarrior_created["project"],
        "taskwarrior.proof"
    );
    assert_has_tag(taskwarrior_created, "taskwarrior");
    assert_eq!(
        taskwarrior_created["recurrence"]["recur"],
        "weekly"
    );

    cleanup_path(&backend_a_storage);
    cleanup_path(&backend_b_storage);
    cleanup_path(&taskwarrior_home);
}

async fn start_sync_server() -> testcontainers::ContainerAsync<GenericImage> {
    GenericImage::new(
        "ghcr.io/gothenburgbitfactory/taskchampion-sync-server",
        "latest",
    )
    .with_exposed_port(8080.tcp())
    .with_wait_for(WaitFor::seconds(3))
    .with_env_var("RUST_LOG", "info")
    .with_env_var("LISTEN", "0.0.0.0:8080")
    .with_env_var(
        "DATA_DIR",
        "/tmp/taskchampion-sync-server",
    )
    .with_env_var("CREATE_CLIENTS", "true")
    .start()
    .await
    .expect("failed to start taskchampion-sync-server")
}

async fn backend(
    sync: TaskChampionSyncConfig,
    storage_path: PathBuf,
) -> axum::Router {
    let state = AppState::from_config(BackendConfig {
        storage: TaskChampionStorageConfig::Sqlite {
            path: storage_path,
            create_if_missing: true,
        },
        sync,
        ..BackendConfig::default()
    })
    .await
    .unwrap();

    server::build_router_with_state(state)
}

async fn create_http_task(router: &axum::Router) -> String {
    let response = request_json(
        router,
        "POST",
        "/tasks",
        json!({
            "description": "Backend synced task"
        }),
    )
    .await;

    response["task"]["id"]
        .as_str()
        .unwrap()
        .to_string()
}

async fn update_http_task(
    router: &axum::Router,
    task_id: &str,
) {
    request_json(
        router,
        "PATCH",
        &format!("/tasks/{task_id}"),
        json!({
            "project": "sync.proof",
            "tags": ["backend", "external-sync"],
            "due": "2026-06-05T10:00:00Z",
            "scheduled": "2026-06-02T10:00:00Z",
            "wait": "2026-06-01T10:00:00Z",
            "add_annotation": "backend annotation",
            "modified_at": "2026-05-30T10:00:00Z",
            "recurrence": {
                "recur": "daily",
                "rtype": "periodic",
                "until": "2026-07-01T10:00:00Z"
            }
        }),
    )
    .await;
}

async fn query_http_tasks(router: &axum::Router) -> Value {
    request_json(
        router,
        "POST",
        "/tasks/query",
        json!({
            "reference_time": "2026-05-30T12:00:00Z",
            "include_waiting": true,
            "include_scheduled": true
        }),
    )
    .await
}

async fn request_json(
    router: &axum::Router,
    method: &str,
    uri: &str,
    body: Value,
) -> Value {
    let request = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .unwrap();
    let response = router.clone().oneshot(request).await.unwrap();
    let status = response.status();
    let bytes = to_bytes(response.into_body(), usize::MAX)
        .await
        .unwrap();

    assert_eq!(
        status,
        StatusCode::OK,
        "unexpected response: {}",
        String::from_utf8_lossy(&bytes)
    );

    serde_json::from_slice(&bytes).unwrap()
}

fn run_task_add(
    taskrc: &Path,
    data: &Path,
    client_id: Uuid,
    secret: &str,
    sync_url: &str,
) {
    run_task(
        taskrc,
        data,
        client_id,
        secret,
        sync_url,
        &[
            "add",
            "project:taskwarrior.proof",
            "+taskwarrior",
            "+external",
            "due:2026-06-08",
            "scheduled:2026-06-03",
            "wait:2026-06-02",
            "recur:weekly",
            "until:2026-07-15",
            "Taskwarrior synced task",
        ],
    );
}

fn run_task_sync(
    taskrc: &Path,
    data: &Path,
    client_id: Uuid,
    secret: &str,
    sync_url: &str,
) {
    run_task(
        taskrc,
        data,
        client_id,
        secret,
        sync_url,
        &["synchronize"],
    );
}

fn task_export(
    taskrc: &Path,
    data: &Path,
    client_id: Uuid,
    secret: &str,
    sync_url: &str,
) -> Value {
    let output = run_task(
        taskrc,
        data,
        client_id,
        secret,
        sync_url,
        &["rc.json.array=on", "export"],
    );
    let stdout = String::from_utf8(output.stdout).unwrap();
    let json_start = stdout.find('[').unwrap_or_else(|| {
        panic!("task export did not contain JSON array: {stdout}")
    });

    serde_json::from_str(&stdout[json_start..]).unwrap()
}

fn run_task(
    taskrc: &Path,
    data: &Path,
    client_id: Uuid,
    secret: &str,
    sync_url: &str,
    args: &[&str],
) -> std::process::Output {
    let output = Command::new("task")
        .arg(format!("rc:{}", taskrc.display()))
        .arg(format!(
            "rc.data.location={}",
            data.display()
        ))
        .arg(format!(
            "rc.sync.server.url={}",
            sync_url
        ))
        .arg(format!(
            "rc.sync.server.client_id={client_id}"
        ))
        .arg(format!(
            "rc.sync.encryption_secret={secret}"
        ))
        .arg("rc.confirmation=off")
        .arg("rc.color=off")
        .args(args)
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "task command failed\nstdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    output
}

fn find_task<'a>(
    tasks: &'a Value,
    description: &str,
) -> &'a Value {
    tasks
        .as_array()
        .unwrap()
        .iter()
        .find(|task| task["description"] == description)
        .unwrap_or_else(|| panic!("task not found: {description}\n{tasks:#}"))
}

fn assert_has_tag(
    task: &Value,
    expected: &str,
) {
    let tags = task["tags"]
        .as_array()
        .cloned()
        .unwrap_or_default();
    assert!(
        tags.iter().any(|tag| tag == expected),
        "missing tag {expected}: {task}"
    );
}

fn temp_path(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!(
        "taskwarrior-frontend-sync-{}-{name}",
        Uuid::new_v4()
    ))
}

fn cleanup_path(path: &Path) {
    let _ = std::fs::remove_file(path);
    let _ = std::fs::remove_dir_all(path);
}
