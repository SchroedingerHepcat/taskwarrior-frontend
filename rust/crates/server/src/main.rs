use server::{BackendConfig, UiStateConfig};
use std::net::{Ipv4Addr, SocketAddr};
use std::path::PathBuf;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let port = args
        .windows(2)
        .find_map(|window| {
            (window[0] == "--port")
                .then(|| window[1].parse::<u16>().ok())
                .flatten()
        })
        .or_else(|| {
            args.iter().find_map(|arg| {
                arg.strip_prefix("--port=")
                    .and_then(|value| value.parse::<u16>().ok())
            })
        })
        .unwrap_or(8080);
    let ui_state_path = configured_ui_state_path(&args);

    let address = SocketAddr::from((Ipv4Addr::LOCALHOST, port));
    server::start_server_with_config(
        address,
        BackendConfig {
            ui_state: UiStateConfig::JsonFile(ui_state_path),
            ..BackendConfig::default()
        },
    )
    .await
}

fn configured_ui_state_path(args: &[String]) -> PathBuf {
    args.windows(2)
        .find_map(|window| {
            (window[0] == "--ui-state-path").then(|| PathBuf::from(&window[1]))
        })
        .or_else(|| {
            args.iter().find_map(|arg| {
                arg.strip_prefix("--ui-state-path=")
                    .map(PathBuf::from)
            })
        })
        .or_else(|| {
            std::env::var_os("TASKWARRIOR_FRONTEND_UI_STATE_PATH")
                .map(PathBuf::from)
        })
        .unwrap_or_else(|| PathBuf::from("taskwarrior-frontend-ui-state.json"))
}
