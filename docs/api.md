# API Notes

## Status

Milestone 4 chooses HTTP with JSON for the first real backend-to-client path.
The server crate now exposes a small HTTP API that the Flutter app uses for
create, read, update, transition, and query flows.

This is still a narrow product-facing boundary. It proves end-to-end behavior
without exposing TaskChampion storage details or claiming that transport,
authentication, pagination, or sync behavior are settled.

The intended storage direction is Taskwarrior 3 and TaskChampion directly. The
HTTP API remains product-facing, while server CRUD handlers now route through
a TaskChampion-backed repository rather than an independent authoritative task
database.

## Current HTTP API

The current HTTP surface covers:

- `GET /health`
- `POST /tasks`
- `GET /tasks/{id}`
- `PATCH /tasks/{id}`
- `POST /tasks/{id}/transition`
- `POST /tasks/query`

The current product-facing operations cover:

- task creation
- task retrieval by id
- task update
- task status transition
- task query, filtering, and sorting by product-facing fields
- dashboard and list data backed by the same query surface

The current query shape uses product-level fields rather than raw
TaskChampion objects or file-oriented Taskwarrior concepts:

- statuses
- required tag
- due-before cutoff
- include-waiting flag
- reference time for waiting-state evaluation
- sort order

The current update shape is still intentionally narrow:

- description update
- project set or clear
- tags replace
- due timestamp update
- due clear
- wait timestamp update
- wait clear
- add annotation
- explicit modified timestamp supplied by the caller

The server still has an internal product-facing dependency operation, but that
operation is not yet part of the current HTTP surface.

## Current Internal Service Boundaries

The server crate now separates:

- request validation and product-facing request types
- HTTP handlers and endpoint specification
- task service logic for create, update, transition, dependency, and query
- TaskChampion-backed repository storage behind a `TaskRepository` trait
- sync orchestration behind a `SyncCoordinator` trait
- future durable TaskChampion storage configuration behind Rust service
  boundaries

This is sufficient for Milestone 4 because it proves the backend can expose a
real wire-level path while keeping compatibility and sync concerns behind Rust
service boundaries.

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
- The compatibility layer may reuse TaskChampion semantics internally where
  that behavior is already authoritative.
- External systems such as issue trackers, voice interfaces, and AI tools
  should call the same backend operations rather than introduce new task
  semantics in the core model.

## Open questions

- sync model
- durable TaskChampion storage configuration
- authentication model
- offline write reconciliation
- pagination and list result shape
- how advanced filtering and saved queries map onto product-facing query
  objects
- how recurring and scheduled task queries should be represented
- whether future protocols are needed beyond the current HTTP boundary
