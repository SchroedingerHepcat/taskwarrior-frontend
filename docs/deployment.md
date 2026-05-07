# Self-Hosted Deployment

This document describes the shortest supported path for running the Rust
backend and Flutter web client for local or self-hosted evaluation.

The deployment keeps the established architecture:

- Flutter talks to this project's backend HTTP API.
- The backend stores tasks in a TaskChampion replica backed by SQLite.
- The backend may sync that replica with a separate TaskChampion sync server.
- Saved views and dashboard layouts are stored as UI configuration.
- No client reads Taskwarrior data files or TaskChampion storage directly.

## Docker Compose

The compose file builds and runs two containers:

- `backend`: Rust HTTP API on `http://127.0.0.1:38180`
- `web`: Flutter web client on `http://127.0.0.1:38181`

From the repository root:

```sh
docker compose -f deploy/docker-compose.yaml up --build
```

Then open:

```text
http://127.0.0.1:38181
```

The web client no longer bakes the backend URL into the build. Open Settings
in the app, enter the backend API URL, and the client persists that value
locally across browser or app restarts.

The container ports remain `8080` for the backend and `80` for the web server.
Only the host-side defaults are shifted to less common ports. Operators can
override them with `BACKEND_HOST_PORT` and `WEB_HOST_PORT`.

If `BACKEND_HOST_PORT` is changed, enter the matching browser-visible backend
URL in the app Settings screen.

## Persistent Data

The backend container mounts a Docker volume at `/data`.

The example backend config stores:

- TaskChampion SQLite task storage at `/data/taskchampion.sqlite`
- shared UI state at `/data/taskwarrior-frontend-ui-state.json`

These files are backend-owned state. Do not synchronize them with an external
file-sync tool. Use TaskChampion sync for multi-device task synchronization.

## Backend Configuration

The compose file mounts:

```text
deploy/backend.compose.toml -> /config/backend.toml
```

For container deployment, set:

```toml
host = "0.0.0.0"
port = 8080

[ui]
state_path = "/data/taskwarrior-frontend-ui-state.json"

[taskchampion.storage]
path = "/data/taskchampion.sqlite"
```

The compose-specific config already uses `0.0.0.0`. The general example config
defaults to `127.0.0.1` for direct local runs. Use `0.0.0.0` when running in
Docker or another environment where the server must accept connections from
outside its own network namespace.

CLI flags override environment variables. Environment variables override the
TOML file. The main operator settings are:

- `--host` or `TASKWARRIOR_FRONTEND_HOST`
- `--port`
- `--ui-state-path` or `TASKWARRIOR_FRONTEND_UI_STATE_PATH`
- `--taskchampion-storage-path` or `TASKCHAMPION_STORAGE_PATH`
- `--config` or `TASKWARRIOR_FRONTEND_CONFIG`

## External TaskChampion Sync Server

This project does not replace a TaskChampion sync server. To pair the backend
with a separately hosted sync server, configure the backend as a TaskChampion
replica client:

```toml
[taskchampion.sync]
url = "https://sync.example.com"
client_id = "00000000-0000-0000-0000-000000000001"
encryption_secret = "replace-me"
allow_plain_http = false
```

Use the TaskChampion sync server URL here, not the Flutter web URL and not this
project's backend API URL.

Plain HTTP should only be enabled for trusted local deployments:

```toml
allow_plain_http = true
```

## Health Checks

Backend health:

```sh
curl -fsS http://127.0.0.1:8080/health
```

For Docker Compose, use the host-side port:

```sh
curl -fsS http://127.0.0.1:38180/health
```

Web health:

```sh
curl -fsS http://127.0.0.1:38181/
```

The compose file also defines container health checks for both services.

## Manual Local Run

To run without containers, use two terminals.

Backend:

```sh
cd rust
mkdir -p data
cargo run -p server -- --config ../deploy/backend.example.toml
```

Flutter web:

```sh
cd flutter_app
flutter pub get
flutter run -d chrome
```

Then enter `http://127.0.0.1:8080` in Settings.

For a release web build:

```sh
cd flutter_app
flutter build web --release --no-wasm-dry-run
```

Serve `flutter_app/build/web` with any static web server.

## Current Limits

- Authentication and authorization are not implemented yet.
- Public sync status and retry controls are planned for Milestone 7.
- Conflict resolution UX is planned for Milestone 7.
- Backup, migration, and restore procedures for the SQLite files still need
  production hardening.
- Compatibility with a separately hosted remote TaskChampion sync server still
  needs an automated deployment proof.
