# API Notes

## Status

The server crate now contains a transport-neutral API skeleton. This is not yet
an HTTP, gRPC, or other wire-level protocol, but it does define the current
backend boundary, request validation, and service-layer seams so the server and
Flutter app can evolve toward the same shape without leaking TaskChampion
internals.

The Flutter app now consumes that boundary through a transport-tolerant client
adapter. Local development currently uses a Dart-side adapter that mirrors the
backend API skeleton without choosing a final wire protocol.

## Current API Skeleton

The current endpoint scaffold covers:

- `GET /health`
- `POST /tasks`
- `PATCH /tasks/{id}`
- `POST /tasks/{id}/transition`
- `POST /tasks/{id}/dependencies`
- `POST /tasks/query`

The current product-facing operations cover:

- task creation
- task update
- task status transition
- task dependency updates
- task query and filtering by product-facing fields

The current query shape uses product-level fields rather than raw
TaskChampion objects or file-oriented Taskwarrior concepts:

- statuses
- required tag
- due-before cutoff
- include-waiting flag
- reference time for waiting-state evaluation

The current update shape is intentionally narrow:

- description update
- due timestamp update
- wait timestamp update
- explicit modified timestamp supplied by the caller

## Current Internal Service Boundaries

The server crate now separates:

- request validation and product-facing request types
- transport-neutral handlers and endpoint specification
- task service logic for create, update, transition, dependency, and query
- repository storage behind a `TaskRepository` trait
- compatibility write preparation behind a `CompatibilityGateway` trait
- sync orchestration behind a `SyncCoordinator` trait

This is sufficient for Milestone 2 because it proves the backend can expose
product-facing operations while keeping compatibility and sync concerns behind
Rust service boundaries.

## Boundary Rules

- The Flutter client should depend on product-facing backend operations rather
  than direct Taskwarrior or TaskChampion data access.
- The Flutter client should keep transport behind a client boundary so the app
  can evolve from local development adapters to HTTP or another protocol later
  without rewriting screen logic.
- Taskwarrior compatibility behavior should remain behind Rust boundaries, not
  in the client.
- The backend should not expose raw TaskChampion storage or replica objects.
- The compatibility layer may reuse TaskChampion semantics internally where
  that behavior is already authoritative.
- External systems such as issue trackers, voice interfaces, and AI tools
  should call the same backend operations rather than introduce new task
  semantics in the core model.

## Open questions

- transport choice
- sync model
- authentication model
- offline write reconciliation
- pagination and list result shape
- how advanced filtering and saved queries map onto product-facing query
  objects
- how recurring and scheduled task queries should be represented
