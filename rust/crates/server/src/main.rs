use std::net::{Ipv4Addr, SocketAddr};

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

    let address = SocketAddr::from((Ipv4Addr::LOCALHOST, port));
    server::start_server(address).await
}
