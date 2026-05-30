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

For the default compose ports, enter:

```text
http://127.0.0.1:38180
```

The app normalizes bare host and port values such as `127.0.0.1:38180` to
`http://127.0.0.1:38180` before saving them.

The container ports remain `8080` for the backend and `80` for the web server.
Only the host-side defaults are shifted to less common ports. Operators can
override them with `BACKEND_HOST_PORT` and `WEB_HOST_PORT`.

If `BACKEND_HOST_PORT` is changed, enter the matching browser-visible backend
URL in the app Settings screen.

## Persistent Data

The backend container bind-mounts `deploy/data` from the repository checkout to
`/data` inside the backend container.

The example backend config stores:

- TaskChampion SQLite task storage at
  `deploy/data/taskchampion.sqlite`
- shared UI state at
  `deploy/data/taskwarrior-frontend-ui-state.json`

These files are backend-owned state. Do not synchronize them with an external
file-sync tool. Use TaskChampion sync for multi-device task synchronization.
The `deploy/data` directory is intentionally ignored by git.

The compose file runs the backend as `BACKEND_UID:BACKEND_GID`, defaulting to
`1000:1000`, so files created under `deploy/data` are usable from a typical
Linux host account. Override those variables if your host user has different
ids.

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

To test local settings without editing committed config, copy the tracked
override example:

```sh
cp deploy/docker-compose.override.example.yaml \
  deploy/docker-compose.override.yaml
```

Then edit `deploy/docker-compose.override.yaml`. That file is ignored by git.
The example uses environment variables because environment overrides the
mounted TOML file.

When using the override file, pass both compose files:

```sh
docker compose \
  -f deploy/docker-compose.yaml \
  -f deploy/docker-compose.override.yaml \
  up --build
```

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

For Docker Compose, use `deploy/docker-compose.override.yaml` to set the
matching environment variables without changing committed TOML:

```yaml
services:
  backend:
    environment:
      TASKCHAMPION_SYNC_URL: "https://sync.example.com"
      TASKCHAMPION_CLIENT_ID: "00000000-0000-0000-0000-000000000001"
      TASKCHAMPION_ENCRYPTION_SECRET: "replace-me"
      TASKCHAMPION_ALLOW_PLAIN_HTTP: "false"
```

Start the stack with both compose files so the override is applied.

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

For container state and logs:

```sh
docker compose -f deploy/docker-compose.yaml ps
docker compose -f deploy/docker-compose.yaml logs backend
docker compose -f deploy/docker-compose.yaml logs web
```

Backend startup failures usually come from invalid TOML, unwritable
`deploy/data`, or sync-server configuration errors. Sync errors are returned
from task requests rather than silently ignored.

## Backup And Restore

For the current single-node deployment, back up the whole `deploy/data`
directory. That keeps TaskChampion SQLite storage and shared UI state together.

Stop the containers before copying the files:

```sh
docker compose -f deploy/docker-compose.yaml down
cp -a deploy/data deploy/data.backup
docker compose -f deploy/docker-compose.yaml up --build
```

To restore, stop the containers, replace `deploy/data` with the backup, and
start the stack again. Do not use file synchronization tools to keep
`deploy/data` live-synchronized between machines; use TaskChampion sync for
task synchronization.

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
flutter build web \
  --release \
  --no-source-maps \
  --no-wasm-dry-run \
  --no-web-resources-cdn
```

Serve `flutter_app/build/web` with any static web server.

This build intentionally bundles Flutter web resources locally. That keeps
self-hosted deployments from depending on Google CDN access for CanvasKit.

If a browser previously loaded an older build, clear site data or unregister
the old Flutter service worker for the web origin before retesting. Otherwise
the browser may continue serving a stale bundle that still references CDN
resources.

## Current Limits

- Authentication and authorization are not implemented yet.
- Public sync status and retry controls are planned for Milestone 7.
- Conflict resolution UX is planned for Milestone 7.
- External TaskChampion sync-server compatibility is covered by the ignored
  `external_taskchampion_sync` Rust integration test, which starts a temporary
  upstream sync-server container and verifies backend and Taskwarrior
  interoperability.
- Migration procedures for future storage format changes still need production
  hardening.
