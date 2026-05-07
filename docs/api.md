# API Notes

## Status

Milestone 4 chooses HTTP with JSON for the first real backend-to-client path.
The server crate now exposes a small HTTP API that the Flutter app uses for
create, read, update, transition, and query flows.

This is still a narrow product-facing boundary. It proves end-to-end behavior
without exposing TaskChampion storage details or claiming that transport,
authentication, pagination, user-facing sync controls, or conflict behavior
are settled.

The intended storage direction is Taskwarrior 3 and TaskChampion directly. The
HTTP API remains product-facing, while server CRUD handlers now route through
a TaskChampion-backed repository rather than an independent authoritative task
database.

The public HTTP API is not the TaskChampion sync protocol. The backend should
act as a TaskChampion replica and may synchronize with a separately hosted
TaskChampion sync server. Flutter and other frontend clients should continue
to use this project's HTTP API rather than talking to that sync server
directly.

## Current HTTP API

The current HTTP surface covers:

- `GET /health`
- `POST /tasks`
- `GET /tasks/{id}`
- `PATCH /tasks/{id}`
- `POST /tasks/{id}/transition`
- `POST /tasks/{id}/board-transition`
- `POST /tasks/query`
- `GET /views`
- `PUT /views/{id}`
- `DELETE /views/{id}`
- `GET /dashboard-layouts`
- `PUT /dashboard-layouts/{id}`
- `DELETE /dashboard-layouts/{id}`

The current product-facing operations cover:

- task creation
- task retrieval by id
- task update
- task status transition
- task query, filtering, and sorting by product-facing fields
- GTD-shaped saved query presets
- board lane transitions for supported lanes
- dashboard and list data backed by the same query surface
- frontend-visible advanced list filtering for the current query fields
- local saved task views backed by product-facing query definitions
- optional backend sharing for saved task views
- dashboard layouts backed by fixed query widgets and saved task views
- local dashboard layout persistence, import/export, and optional backend
  sharing

The current query shape uses product-level fields rather than raw
TaskChampion objects or file-oriented Taskwarrior concepts:

- query preset: `custom`, `inbox`, `next_actions`, `waiting`, or `review`
- statuses
- project
- no-project flag
- required tag
- no-tags flag
- due date range
- scheduled date range
- waiting date range
- include-waiting flag
- include-scheduled flag
- include-blocked flag based on unresolved dependencies
- reference time for waiting-state evaluation
- sort order

The saved query presets are GTD-shaped backend semantics. Clients request the
preset rather than reimplementing waiting, scheduled, stale-review, or
dependency rules.

Saved task views are separate from task storage. A saved view contains an id,
name, update timestamp, and product-facing query filter. Flutter persists
local saved views for client restart behavior and may selectively push or pull
individual views through the backend `/views` endpoints for sharing between
clients. These endpoints store view definitions only; they do not store tasks,
TaskChampion replica data, or Taskwarrior data files.

Dashboard layouts are also separate from task storage. A dashboard layout
contains an id, name, enabled fixed widget ids, saved-view-backed dashboard
widgets, update timestamp, and product-facing query filters copied from saved
views. Flutter persists the active layout locally and may selectively push or
pull layouts through `/dashboard-layouts`. These endpoints store layout
definitions only; dashboard task data is still loaded through `/tasks/query`.
The backend persists shared saved views and dashboard layouts to a JSON UI
state file when configured with durable UI state. The server binary uses
`taskwarrior-frontend-ui-state.json` by default, and the path can be changed
with `--ui-state-path` or `TASKWARRIOR_FRONTEND_UI_STATE_PATH`.

The current update shape is still intentionally narrow:

- description update
- project set or clear
- tags replace
- due timestamp update
- due clear
- scheduled timestamp update
- scheduled clear
- wait timestamp update
- wait clear
- recurrence property update
- recurrence property clear
- add annotation
- explicit modified timestamp supplied by the caller

Recurrence update currently preserves Taskwarrior-compatible recurrence
properties. It does not expose a separate recurrence instance generator, and
clients must not create future recurrence task instances themselves. The
intended API behavior is to submit supported Taskwarrior recurrence settings
to the backend and let Taskwarrior or TaskChampion handle recurrence
execution.

The server still has an internal product-facing dependency operation, but that
operation is not yet part of the current HTTP surface.

The current HTTP surface does not expose sync configuration, TaskChampion
replica details, or TaskChampion sync-server credentials. Those remain backend
setup concerns.

## Current Internal Service Boundaries

The server crate now separates:

- request validation and product-facing request types
- HTTP handlers and endpoint specification
- task service logic for create, update, transition, dependency, and query
- TaskChampion-backed repository storage behind a `TaskRepository` trait
- sync orchestration behind a `SyncCoordinator` trait
- TaskChampion storage configuration behind Rust service boundaries, with
  in-memory storage for tests and SQLite-backed storage for durable paths
- TaskChampion sync configuration behind Rust service boundaries, covering
  disabled sync, local TaskChampion sync-server tests, and remote sync-server
  connection details
- durable backend UI configuration for shared saved views and dashboard
  layouts, separate from TaskChampion task storage

The server boundary now proves that local TaskChampion sync can move tasks
between two backend replicas without exposing TaskChampion internals to
Flutter. It does not yet prove compatibility with a separately hosted remote
TaskChampion sync server.

Flutter stores the product backend API URL locally and can change it from the
Settings screen. That setting is the URL of this Rust backend, not the
TaskChampion sync server URL.

The Flutter task list exposes the current custom query fields directly:
project and tag are selected from values returned by the backend task list,
with explicit no-project and no-tags choices. Due, scheduled, and waiting
filters are represented as date ranges. The client builds product-facing query
objects only; the backend remains authoritative for applying those filters.

The internal TaskChampion sync configuration maps to the TaskChampion crate's
sync client API:

- local test sync uses a server directory
- remote sync uses server URL, client id, and encryption secret
- HTTPS is required for remote sync unless plain HTTP is explicitly allowed in
  backend setup
- TLS trust comes from the TaskChampion HTTP sync client stack with rustls
  webpki roots enabled
- task storage uses in-memory TaskChampion storage for tests or SQLite-backed
  TaskChampion storage for durable backend paths

## Boundary Rules

- The Flutter client should depend on product-facing backend operations rather
  than direct Taskwarrior or TaskChampion data access.
- The Flutter client should keep HTTP behind a client boundary so the app can
  evolve without rewriting screen logic.
- Taskwarrior compatibility behavior should remain behind Rust boundaries, not
  in the client.
- The backend should not expose raw TaskChampion storage or replica objects.
- The backend should route task CRUD through Taskwarrior or TaskChampion as the
  storage and mutation authority.
- The backend may sync its TaskChampion replica with an external TaskChampion
  sync server, but that server is not exposed as the frontend API.
- The compatibility layer may reuse TaskChampion semantics internally where
  that behavior is already authoritative.
- External systems such as issue trackers, voice interfaces, and AI tools
  should call the same backend operations rather than introduce new task
  semantics in the core model.

## Open questions

- public sync status and control endpoints, if any
- externally hosted TaskChampion sync-server compatibility test coverage
- authentication model
- offline write reconciliation
- conflict behavior across synchronized replicas
- pagination and list result shape
- how recurring task queries should be represented
- whether future protocols are needed beyond the current HTTP boundary
