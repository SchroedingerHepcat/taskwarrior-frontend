# taskwarrior-frontend

A self-hosted project-management application with Taskwarrior compatibility as
a first-class requirement.

This repository currently contains the initial scaffold for:

- a Rust workspace with task domain, compatibility, and server crates
- a responsive Flutter client shell with Android, Linux, and web scaffolding
- architecture, roadmap, and API boundary notes aligned to the current build

The Rust server currently includes a small HTTP API with validated
product-facing operations for health, create, get, update, status transition,
and query filtering. Server CRUD now routes through TaskChampion-backed
storage rather than a separate custom task database. It does not yet implement
authentication, user-facing sync controls, or conflict handling.

The Rust backend has internal configuration for in-memory TaskChampion storage
used by tests and SQLite-backed TaskChampion storage for durable deployment
paths. It also has an internal sync coordinator boundary and a local
TaskChampion sync proof between two backend replicas.
The server binary now defaults to SQLite TaskChampion storage at
`taskwarrior-frontend-tasks.sqlite`; set `--taskchampion-storage-path` or
`TASKCHAMPION_STORAGE_PATH` to choose another location.
Backend settings can also be loaded from a TOML configuration file with
`--config` or `TASKWARRIOR_FRONTEND_CONFIG`. CLI flags override environment
variables, and environment variables override the configuration file.
Set `--host` or `TASKWARRIOR_FRONTEND_HOST` when the backend must bind to an
address other than `127.0.0.1`, such as `0.0.0.0` inside a container.

The intended sync model is to let this backend act as a TaskChampion replica
that can connect to a separately hosted TaskChampion sync server. This project
is intended to provide a good frontend and product API for TaskChampion data,
not replace the upstream TaskChampion sync server. Configure remote sync with
`--taskchampion-sync-url`, `--taskchampion-client-id`, and
`--taskchampion-encryption-secret`, or the matching
`TASKCHAMPION_SYNC_URL`, `TASKCHAMPION_CLIENT_ID`, and
`TASKCHAMPION_ENCRYPTION_SECRET` environment variables. Plain HTTP sync
servers require `--taskchampion-allow-plain-http` or
`TASKCHAMPION_ALLOW_PLAIN_HTTP=true`.

See `deploy/backend.example.toml` for an example sectioned configuration
file. See `docs/deployment.md` for the Docker Compose self-hosting path.
For Docker Compose sync-server testing without editing committed files, copy
`deploy/docker-compose.override.example.yaml` to
`deploy/docker-compose.override.yaml` and put local credentials there. The
override file is ignored by git. Use both compose files when starting the
stack so the override is applied.

The Flutter app currently includes responsive dashboard, list, board, and
detail screens backed by that HTTP API. It now proves end-to-end create,
update, complete, filtered list, saved GTD query, and board-lane transition
flows against the Rust backend. The task list also exposes an advanced filter
panel for backend-owned query fields such as workflow preset, project, tag,
no-project, no-tags, date ranges, status, visibility flags, and sort order.
Saved views can be persisted locally, imported and exported as JSON, and
selectively shared through the Rust backend as product-facing query
definitions.
Dashboard layouts can use fixed widgets and saved-view-backed panels. The
active layout supports naming and saved-view panel ordering, is persisted
locally, can be imported or exported as JSON, and can be selectively shared
through the Rust backend as presentation/query configuration. Backend sharing
for saved views and dashboard layouts persists across backend restarts through
a JSON UI state file. The server binary uses
`taskwarrior-frontend-ui-state.json` by default; set `--ui-state-path` or
`TASKWARRIOR_FRONTEND_UI_STATE_PATH` to choose another location.
Recurrence properties are preserved through the Taskwarrior-compatible model;
the Flutter detail screen can edit Taskwarrior-compatible recurrence settings
for existing tasks. Recurrence instance generation remains delegated to
Taskwarrior or TaskChampion-compatible semantics, and the app does not spawn
recurrence child tasks itself.

The Flutter app stores the configured backend API URL locally. If no saved URL
exists, the app starts on Settings and asks for the Rust backend API URL before
loading task data. Backend URLs are not baked into Flutter builds.
