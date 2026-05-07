use serde::Deserialize;
use server::{BackendConfig, UiStateConfig};
use std::fs;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use taskwarrior_compat::{
    TaskChampionRemoteSyncConfig, TaskChampionStorageConfig,
    TaskChampionSyncConfig,
};
use uuid::Uuid;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let file_config = load_file_config(&args)?;
    let port = configured_port(&args, &file_config);
    let host = configured_host(&args, &file_config)?;
    let ui_state_path = configured_ui_state_path(&args, &file_config);
    let storage = configured_storage(&args, &file_config);
    let sync = configured_sync(&args, &file_config)?;

    let address = SocketAddr::from((host, port));
    server::start_server_with_config(
        address,
        BackendConfig {
            storage,
            sync,
            ui_state: UiStateConfig::JsonFile(ui_state_path),
        },
    )
    .await
}

#[derive(Clone, Debug, Default, Deserialize)]
struct FileConfig {
    host: Option<String>,
    port: Option<u16>,
    ui: Option<UiFileConfig>,
    taskchampion: Option<TaskChampionFileConfig>,
}

#[derive(Clone, Debug, Default, Deserialize)]
struct UiFileConfig {
    state_path: Option<String>,
}

#[derive(Clone, Debug, Default, Deserialize)]
struct TaskChampionFileConfig {
    storage: Option<TaskChampionStorageFileConfig>,
    sync: Option<TaskChampionSyncFileConfig>,
}

#[derive(Clone, Debug, Default, Deserialize)]
struct TaskChampionStorageFileConfig {
    path: Option<String>,
}

#[derive(Clone, Debug, Default, Deserialize)]
struct TaskChampionSyncFileConfig {
    url: Option<String>,
    client_id: Option<String>,
    encryption_secret: Option<String>,
    allow_plain_http: Option<bool>,
}

fn load_file_config(args: &[String]) -> std::io::Result<FileConfig> {
    let Some(path) = arg_value(args, "--config")
        .or_else(|| std::env::var("TASKWARRIOR_FRONTEND_CONFIG").ok())
    else {
        return Ok(FileConfig::default());
    };

    let raw = fs::read_to_string(&path)?;
    toml::from_str(&raw).map_err(|error| {
        std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("invalid backend config file {path}: {error}"),
        )
    })
}

fn configured_port(
    args: &[String],
    file: &FileConfig,
) -> u16 {
    arg_value(args, "--port")
        .and_then(|value| value.parse::<u16>().ok())
        .or(file.port)
        .unwrap_or(8080)
}

fn configured_host(
    args: &[String],
    file: &FileConfig,
) -> std::io::Result<IpAddr> {
    let raw = config_value(
        args,
        "--host",
        "TASKWARRIOR_FRONTEND_HOST",
        file.host.as_deref(),
    )
    .unwrap_or_else(|| Ipv4Addr::LOCALHOST.to_string());

    raw.parse::<IpAddr>().map_err(|error| {
        std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("invalid backend host {raw}: {error}"),
        )
    })
}

fn configured_ui_state_path(
    args: &[String],
    file: &FileConfig,
) -> PathBuf {
    config_value(
        args,
        "--ui-state-path",
        "TASKWARRIOR_FRONTEND_UI_STATE_PATH",
        file.ui
            .as_ref()
            .and_then(|ui| ui.state_path.as_deref()),
    )
    .map(PathBuf::from)
    .unwrap_or_else(|| PathBuf::from("taskwarrior-frontend-ui-state.json"))
}

fn configured_storage(
    args: &[String],
    file: &FileConfig,
) -> TaskChampionStorageConfig {
    let path = config_value(
        args,
        "--taskchampion-storage-path",
        "TASKCHAMPION_STORAGE_PATH",
        file.taskchampion
            .as_ref()
            .and_then(|taskchampion| taskchampion.storage.as_ref())
            .and_then(|storage| storage.path.as_deref()),
    )
    .map(PathBuf::from)
    .unwrap_or_else(|| PathBuf::from("taskwarrior-frontend-tasks.sqlite"));

    TaskChampionStorageConfig::Sqlite {
        path,
        create_if_missing: true,
    }
}

fn configured_sync(
    args: &[String],
    file: &FileConfig,
) -> std::io::Result<TaskChampionSyncConfig> {
    let Some(url) = config_value(
        args,
        "--taskchampion-sync-url",
        "TASKCHAMPION_SYNC_URL",
        file.taskchampion
            .as_ref()
            .and_then(|taskchampion| taskchampion.sync.as_ref())
            .and_then(|sync| sync.url.as_deref()),
    ) else {
        return Ok(TaskChampionSyncConfig::Disabled);
    };
    let client_id = required_config(
        args,
        "--taskchampion-client-id",
        "TASKCHAMPION_CLIENT_ID",
        file.taskchampion
            .as_ref()
            .and_then(|taskchampion| taskchampion.sync.as_ref())
            .and_then(|sync| sync.client_id.as_deref()),
    )?;
    let encryption_secret = required_config(
        args,
        "--taskchampion-encryption-secret",
        "TASKCHAMPION_ENCRYPTION_SECRET",
        file.taskchampion
            .as_ref()
            .and_then(|taskchampion| taskchampion.sync.as_ref())
            .and_then(|sync| sync.encryption_secret.as_deref()),
    )?;
    let allow_plain_http = flag_enabled(
        args,
        "--taskchampion-allow-plain-http",
        "TASKCHAMPION_ALLOW_PLAIN_HTTP",
        file.taskchampion
            .as_ref()
            .and_then(|taskchampion| taskchampion.sync.as_ref())
            .and_then(|sync| sync.allow_plain_http),
    );

    Ok(TaskChampionSyncConfig::Remote(
        TaskChampionRemoteSyncConfig {
            url,
            client_id: Uuid::parse_str(&client_id).map_err(|error| {
                std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    format!("invalid TASKCHAMPION_CLIENT_ID: {error}"),
                )
            })?,
            encryption_secret: encryption_secret.into_bytes(),
            allow_plain_http,
        },
    ))
}

fn config_value(
    args: &[String],
    flag: &str,
    env: &str,
    file_value: Option<&str>,
) -> Option<String> {
    arg_value(args, flag)
        .or_else(|| {
            std::env::var(env)
                .ok()
                .filter(|value| !value.trim().is_empty())
        })
        .or_else(|| {
            file_value
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_string)
        })
}

fn required_config(
    args: &[String],
    flag: &str,
    env: &str,
    file_value: Option<&str>,
) -> std::io::Result<String> {
    config_value(args, flag, env, file_value).ok_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("{env} is required when TASKCHAMPION_SYNC_URL is set"),
        )
    })
}

fn arg_value(
    args: &[String],
    flag: &str,
) -> Option<String> {
    args.windows(2)
        .find_map(|window| (window[0] == flag).then(|| window[1].clone()))
        .or_else(|| {
            let prefix = format!("{flag}=");
            args.iter()
                .find_map(|arg| arg.strip_prefix(&prefix).map(str::to_string))
        })
}

fn flag_enabled(
    args: &[String],
    flag: &str,
    env: &str,
    file_value: Option<bool>,
) -> bool {
    args.iter().any(|arg| arg == flag)
        || std::env::var(env)
            .map(|value| matches!(value.as_str(), "1" | "true" | "yes"))
            .unwrap_or(false)
        || file_value.unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::{
        configured_host, configured_port, configured_storage, configured_sync,
        load_file_config, FileConfig, TaskChampionFileConfig,
        TaskChampionStorageFileConfig,
    };
    use std::net::{IpAddr, Ipv4Addr};
    use std::path::PathBuf;
    use taskwarrior_compat::{
        TaskChampionStorageConfig, TaskChampionSyncConfig,
    };

    #[test]
    fn parses_remote_taskchampion_sync_arguments() {
        let args = vec![
            "server".to_string(),
            "--taskchampion-sync-url".to_string(),
            "http://127.0.0.1:9000".to_string(),
            "--taskchampion-client-id".to_string(),
            "00000000-0000-0000-0000-000000000001".to_string(),
            "--taskchampion-encryption-secret".to_string(),
            "test-secret".to_string(),
            "--taskchampion-allow-plain-http".to_string(),
        ];

        let sync = configured_sync(&args, &FileConfig::default()).unwrap();

        let TaskChampionSyncConfig::Remote(config) = sync else {
            panic!("expected remote sync config");
        };
        assert_eq!(config.url, "http://127.0.0.1:9000");
        assert_eq!(
            config.encryption_secret,
            b"test-secret".to_vec()
        );
        assert!(config.allow_plain_http);
    }

    #[test]
    fn parses_backend_configuration_file() {
        let path = temp_config_path();
        std::fs::write(
            &path,
            r#"
host = "0.0.0.0"
port = 9090

[taskchampion.storage]
path = "./tasks.sqlite"

[taskchampion.sync]
url = "http://127.0.0.1:9000"
client_id = "00000000-0000-0000-0000-000000000001"
encryption_secret = "test-secret"
allow_plain_http = true
"#,
        )
        .unwrap();
        let args = vec![
            "server".to_string(),
            "--config".to_string(),
            path.to_string_lossy().to_string(),
        ];
        let file = load_file_config(&args).unwrap();

        assert_eq!(configured_port(&args, &file), 9090);
        assert_eq!(
            configured_host(&args, &file).unwrap(),
            IpAddr::V4(Ipv4Addr::UNSPECIFIED)
        );
        let sync = configured_sync(&args, &file).unwrap();
        let TaskChampionSyncConfig::Remote(config) = sync else {
            panic!("expected remote sync config");
        };
        assert_eq!(config.url, "http://127.0.0.1:9000");
        assert!(config.allow_plain_http);

        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn command_line_overrides_backend_configuration_file() {
        let file = FileConfig {
            port: Some(9090),
            taskchampion: Some(TaskChampionFileConfig {
                storage: Some(TaskChampionStorageFileConfig {
                    path: Some("./file.sqlite".to_string()),
                }),
                ..TaskChampionFileConfig::default()
            }),
            ..FileConfig::default()
        };
        let args = vec![
            "server".to_string(),
            "--port".to_string(),
            "8081".to_string(),
            "--taskchampion-storage-path".to_string(),
            "./cli.sqlite".to_string(),
        ];

        assert_eq!(configured_port(&args, &file), 8081);
        let storage = configured_storage(&args, &file);

        let TaskChampionStorageConfig::Sqlite { path, .. } = storage else {
            panic!("expected sqlite storage config");
        };
        assert_eq!(path.to_string_lossy(), "./cli.sqlite");
    }

    #[test]
    fn parses_backend_host_configuration() {
        let file = FileConfig {
            host: Some("127.0.0.1".to_string()),
            ..FileConfig::default()
        };
        let args = vec![
            "server".to_string(),
            "--host".to_string(),
            "0.0.0.0".to_string(),
        ];

        assert_eq!(
            configured_host(&args, &file).unwrap(),
            IpAddr::V4(Ipv4Addr::UNSPECIFIED)
        );
    }

    #[test]
    fn defaults_to_sqlite_taskchampion_storage() {
        let args = vec!["server".to_string()];
        let storage = configured_storage(&args, &FileConfig::default());

        let TaskChampionStorageConfig::Sqlite {
            path,
            create_if_missing,
        } = storage
        else {
            panic!("expected sqlite storage config");
        };
        assert_eq!(
            path.to_string_lossy(),
            "taskwarrior-frontend-tasks.sqlite"
        );
        assert!(create_if_missing);
    }

    fn temp_config_path() -> PathBuf {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();

        std::env::temp_dir().join(format!(
            "taskwarrior-frontend-config-{now}.toml"
        ))
    }
}
