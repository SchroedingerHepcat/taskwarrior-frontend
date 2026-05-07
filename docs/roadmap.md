# Roadmap

## Planning Assumptions

- Taskwarrior compatibility remains a first-class requirement.
- The Rust backend remains the source of product-facing operations.
- The compatibility layer should reuse TaskChampion semantics where possible.
- Taskwarrior 3 and TaskChampion are the intended durable task storage and
  mutation authority.
- Server CRUD operations should call into Taskwarrior or TaskChampion through
  Rust boundaries rather than write to an independent task database.
- The backend should be able to synchronize its TaskChampion replica with a
  separately hosted TaskChampion sync server.
- This project should provide a frontend and product API for TaskChampion data,
  not replace the upstream TaskChampion sync server.
- Flutter remains the shared client for Android, Linux desktop, and web.
- This roadmap is ordered to prove architecture and semantics before heavy UI
  or deployment work.
- Future integrations with issue trackers, voice assistants, and AI tools are
  treated as expansion requirements for architecture, not early milestones.

## Milestone 1: Compatibility Spike

Status: in progress

### Goal

Prove that a Rust domain model and compatibility layer can represent the
direction of Taskwarrior 3 and TaskChampion-compatible behavior without
designing around direct task data files.

### Deliverables

- Rust workspace with `core`, `taskwarrior_compat`, and `server` crates.
- Initial task domain model boundaries in `core`.
- Initial compatibility boundary in `taskwarrior_compat`.
- Initial proof that product-facing backend operations can translate through
  the compatibility layer without exposing raw TaskChampion objects.
- Documentation describing the selected architecture and rejected options.
- Automated tests for the first core and compatibility model assumptions.

### Acceptance Criteria

- The Rust workspace builds and tests cleanly.
- The code structure clearly separates core semantics from compatibility logic.
- The architecture documents state that file-based synchronization is not the
  primary design.
- The compatibility direction is described without claiming unsupported
  features.
- The backend boundary demonstrates product-facing operations that do not leak
  raw TaskChampion storage or replica details.

### Risks

- The core model may be too narrow and need restructuring once recurring and
  scheduled tasks are added.
- The compatibility boundary may become unclear if the spike mixes storage and
  semantic concerns.
- Early tests may prove only shape, not behavior.

## Milestone 2: Backend API Scaffold

Status: in progress

### Goal

Establish a backend service boundary that can support all clients while keeping
task semantics in Rust and leaving room for future sync and integration work.

### Deliverables

- Server routing or handler scaffold with health and task operation endpoints.
- API document covering task CRUD, filtering, and status transitions.
- Internal service boundaries for storage, sync orchestration, and
  compatibility logic.
- Product-facing backend operations that can translate into
  TaskChampion-aware mutations through the compatibility layer.
- A storage direction that treats Taskwarrior or TaskChampion as the
  authoritative task store for CRUD events.
- Test coverage for request validation and service wiring.

### Acceptance Criteria

- The backend exposes a documented, test-covered API skeleton.
- The API can represent create, update, complete, and query flows at a minimum.
- API design does not expose Taskwarrior data files directly.
- API design does not expose raw TaskChampion storage or replica objects.
- Task CRUD is designed to route through Taskwarrior or TaskChampion, not a
  separate authoritative task database.
- The service boundary leaves room for future two-way sync adapters for
  GitHub, GitLab, Gitea, and similar sources.
- The service boundary leaves room for future voice and AI-driven command
  adapters without pushing those concerns into the core model.

### Risks

- The API may freeze too early before recurring and GTD semantics are proven.
- Storage abstractions may become speculative if they are designed before real
  write paths exist.
- A generic repository abstraction may hide the required TaskChampion-backed
  CRUD path if it remains the only storage proof.
- Integration extensibility may be asserted in structure but not yet validated.

## Milestone 3: Flutter Shell

Status: complete

### Goal

Create a usable cross-platform client shell that can run on Android, Linux
desktop, and web against the backend scaffold.

### Deliverables

- Flutter application shell with routing, app state boundaries, and backend
  client integration points.
- Initial layout system for mobile, desktop, and web.
- Layout should support both landscape and portrait views on the web and desktop
  versions
- Good layout should be used for different sized screens (i.e. the desktop/web
  versions should not just be a scaled up version of the phone, but rather
  should use the extra space on a larger screen wisely)
- Placeholder screens for dashboard, task list, board view, and task detail.
- Design direction for a contemporary UI without locking into premature visual
  polish.
- Widget and integration tests for shell navigation and API wiring.

### Acceptance Criteria

- The Flutter app builds and tests on the supported targets in CI.
- The shell can connect to the backend scaffold in local development.
- The code structure supports configurable dashboards, list views, board
  views, and advanced filtering without forcing a rewrite.
- The UI structure supports drag-and-drop board interaction on platforms where
  it is appropriate.

### Risks

- Responsive layout needs may force early restructuring if web and desktop are
  treated as mobile-only screens.
- A visual shell can hide missing domain capability if not tied to real data.
- Drag-and-drop interaction can create platform-specific behavior differences.

## Milestone 4: End-To-End Create, Update, And Complete Flows

Status: complete

### Goal

Deliver the first real user flows through backend and Flutter layers for task
creation, editing, completion, and querying.

### Deliverables

- End-to-end create, update, complete, and reopen flows.
- Task list presentation with sorting and filtering.
- Core task detail editing for status, description, project, tags, dates, and
  annotations as supported by the model at this stage.
- Initial configurable dashboard widgets backed by real task queries.
- End-to-end tests covering API and UI behavior.

### Acceptance Criteria

- A user can create, edit, complete, and view tasks from the Flutter client
  against the backend.
- Backend and UI tests cover the main flows, not just unit-level pieces.
- Filtering is explicit, test-covered, and does not require client-side
  reimplementation of server semantics.
- Dashboard widgets are configurable enough to prove the architecture, even if
  the widget set is still small.

### Risks

- The first real flows may expose missing fields in the core task model.
- Query and filter semantics may diverge between backend and UI if not kept in
  one place.
- Dashboard configuration can expand scope quickly if not kept narrow.

### Notes For This Milestone

- Milestone 3 proved a transport-tolerant client boundary, not a final
  backend wire protocol. This milestone chooses HTTP for the first real
  backend path and wires the shell to it in local development and integration
  testing.
- Pagination and list envelope shape remain open and may affect the first real
  list and dashboard flows.
- The current backend update shape is intentionally narrow and will likely need
  expansion once task detail editing includes more Taskwarrior-aligned fields.
- Advanced filtering remains open beyond status, tag, due cutoff, and
  waiting-state handling.
- It is still not fully proven which mutation paths should call more directly
  into TaskChampion semantics and which should remain product-layer logic.
- The current HTTP surface does not yet expose every internal service
  operation, including dependency mutation, because this milestone only needed
  the first end-to-end CRUD and query path.
- The current implementation now routes server CRUD through a TaskChampion
  `Replica` using TaskChampion's in-memory storage backend. Future deployment
  work should replace that with durable TaskChampion configuration rather than
  a custom authoritative database.

## Milestone 5: Taskwarrior Semantics, GTD, And Advanced Views

Status: in progress

### Goal

Expand the product from basic task CRUD into real Taskwarrior-compatible task
management, including recurring tasks, GTD-oriented workflows, list views,
board views, and advanced filtering.

### Deliverables

- Recurrence viewing and editing, including every schedule option supported by
  Taskwarrior.
- Scheduled and waiting task behavior as supported by the compatibility model.
- GTD-oriented organization primitives such as inbox-style capture, next
  actions, and review-friendly filtered views.
- Advanced filtering and saved query support.
- Kanban-style boards with drag-and-drop transitions where the model supports
  them.
- Tests proving semantic behavior for recurrence, scheduling, and filtered
  views.

### Acceptance Criteria

- Recurring tasks and complex schedule options can be created or modified
  through the product interface and are covered by automated compatibility
  tests.
- The app does not create recurrence child tasks itself; Taskwarrior or
  TaskChampion remains responsible for recurrence execution.
- GTD-style task management is possible without bypassing the main task model.
- List and board views are both backed by the same server semantics.
- Drag-and-drop board changes translate into valid task updates and are test
  covered.
- Advanced filtering works across backend and clients without per-client
  reinterpretation.

### Risks

- Full recurrence support may be substantially more complex than the first core
  model suggests.
- GTD support can become vague unless concrete workflows are tested.
- Board interactions may oversimplify status and project semantics if they are
  designed for presentation first.

### Notes For This Milestone

- Recurrence support is implemented as Taskwarrior-compatible property
  preservation and round-trip coverage for `recur`, `rtype`, `until`,
  `parent`, `mask`, and `imask`. The application does not locally generate
  future recurrence instances; that remains delegated to Taskwarrior or
  TaskChampion-compatible semantics.
- Scheduled and waiting behavior is represented in the core model, the
  compatibility layer, backend filters, and Flutter task models.
- GTD support now includes backend-owned saved query presets for inbox, next
  actions, waiting, and review-shaped views.
- Advanced filtering now includes project, no-project, tag, no-tags, due
  ranges, waiting ranges, scheduled ranges, blocked, status, preset, and sort
  fields.
- The Flutter advanced filter panel applies changes immediately, offers
  project and tag dropdowns based on available backend task values, includes
  no-project and no-tags options, and uses typeable date-range inputs with
  picker buttons.
- Saved task views can be created, updated, selected, deleted, imported,
  exported, persisted locally across Flutter app restarts, and selectively
  pushed to or retrieved from the backend for sharing between clients.
- Dashboard layouts now support fixed widgets plus saved-view-backed panels,
  local persistence across Flutter app restarts, JSON import/export, and
  selective backend push/pull sharing.
- Backend-shared saved views and dashboard layouts now persist across backend
  restarts through a durable UI state file.
- Board drag-and-drop now calls a product-facing backend board transition
  operation for pending, waiting, and completed lanes.
- Platform-specific board polish remains part of Milestone 8.
- Recurrence instance generation, conflict behavior, and multi-replica
  recurrence behavior remain Taskwarrior or TaskChampion responsibilities. This
  app should prove that it can set and modify recurrence options without
  spawning child tasks itself.

### Remaining Work

- Add frontend controls for creating and modifying every Taskwarrior-supported
  recurrence schedule option on existing tasks.
- Add tests proving recurrence controls submit Taskwarrior-compatible
  recurrence properties without spawning child tasks in the client.
- Refine dashboard layout editing with ordering, naming, and platform-specific
  presentation polish.

## Milestone 6: Self-Hosted Deployment

### Goal

Make the system practical to run as a self-hosted application with documented
deployment and basic operational controls.

### Deliverables

- Production-oriented backend and frontend deployment configuration.
- Containerized local and self-hosted deployment path.
- Configuration for storage, networking, and client base URLs.
- Taskwarrior or TaskChampion-backed storage configuration for the backend.
- Configuration for connecting the backend TaskChampion replica to an external
  TaskChampion sync server.
- Deployment documentation for a single-node self-hosted setup.
- Deployment documentation for pairing this backend with a separately hosted
  TaskChampion sync server.
- Basic operational checks, logs, and health endpoints.

### Acceptance Criteria

- A self-hosted user can deploy the backend and web client from documented
  steps.
- Health checks and logs are sufficient to debug startup and connectivity
  failures.
- The deployment path does not rely on external file synchronization.
- The deployment path uses Taskwarrior or TaskChampion as the task storage
  authority through backend-controlled Rust APIs.
- A self-hosted user can configure the backend to sync with an external
  TaskChampion sync server without exposing TaskChampion internals to Flutter.
- CI validates the deployment artifacts at least to the level of build and
  configuration sanity.

### Risks

- Deployment work can expose missing assumptions about storage and migration.
- Self-hosting needs may surface authentication and backup concerns earlier
  than planned.
- Web and backend deployment may be straightforward while desktop and Android
  distribution still lag behind.

### Notes For This Milestone

- Authentication and authorization are still open carryover from Milestone 2.
- Internal backend configuration now supports in-memory TaskChampion storage
  for tests and SQLite-backed TaskChampion storage for durable paths.
- Internal backend sync configuration now models disabled sync, local
  TaskChampion sync-server tests, and remote sync-server connection details,
  including URL, client id, encryption secret, and plain-HTTP policy.
- Backend UI configuration for shared saved views and dashboard layouts can be
  persisted with `--ui-state-path` or
  `TASKWARRIOR_FRONTEND_UI_STATE_PATH`.
- The server binary now accepts durable TaskChampion storage configuration and
  remote TaskChampion sync-server configuration.
- Backend configuration can now be loaded from a sectioned TOML file, with CLI
  and environment overrides.
- HTTP task reads and writes now perform configured TaskChampion sync at the
  backend boundary.
- Deployment packaging, migration, backup, and operational validation for
  durable TaskChampion storage remain open.
- A real external TaskChampion sync-server deployment test remains open.
- User-facing sync status and retry controls remain part of Milestone 7.

## Milestone 7: Sync, Error, And Conflict UX

### Goal

Make synchronization and failure behavior understandable and recoverable across
clients, especially once multiple devices are in use.

### Deliverables

- Sync state model and user-visible status indicators.
- Backend synchronization with an external TaskChampion sync server.
- Error handling for network failures, invalid updates, and server rejections.
- Conflict detection and conflict resolution UX.
- Offline and reconnection behavior definitions for clients where supported.
- Test coverage for sync and conflict cases.

### Acceptance Criteria

- Clients surface sync state and error conditions clearly enough for a user to
  recover.
- Conflicts are handled by defined product behavior rather than accidental
  last-write-wins semantics.
- Backend and client tests cover representative conflict and retry scenarios.
- Tests prove backend sync behavior against an external or test TaskChampion
  sync server.
- The sync architecture still leaves room for future external-source adapters.

### Risks

- Conflict handling can force changes in the task model and API.
- Offline support may be significantly different across Android, desktop, and
  web.
- External-source synchronization will add complexity beyond first-party sync.

### Notes For This Milestone

- Sync orchestration now has an internal coordinator seam and a local
  TaskChampion sync proof between two backend replicas.
- HTTP task writes now sync after local TaskChampion mutation, and HTTP task
  reads sync before serving product queries when sync is configured.
- Compatibility with a separately hosted TaskChampion sync server remains open
  until tested against that server or an equivalent test service.
- Offline write reconciliation remains open.
- A durable error model from the API boundary will likely need to solidify here
  if it has not already been finalized earlier.

## Milestone 8: Polish For Android, Web, And Desktop

### Goal

Bring the product to a consistent, usable level across all supported clients
with attention to interaction quality, performance, and platform-specific fit.

### Deliverables

- Responsive layouts and interaction polish for mobile, desktop, and web.
- Refined dashboard configuration and presentation.
- Improved board interaction, filtering UX, and task detail ergonomics.
- Performance work for large task sets and filter-heavy views.
- Platform-specific review for Android, Linux desktop, and web behavior.

### Acceptance Criteria

- Android, Linux desktop, and web each provide a coherent primary workflow.
- The interface supports contemporary expectations for responsiveness and
  clarity without diverging into platform-specific task semantics.
- Dashboard, list, and board views all remain usable with realistic task
  volumes.
- Cross-platform testing covers the primary interaction model for each target.

### Risks

- Visual polish can consume time needed for unresolved semantic issues.
- Performance problems may expose weaknesses in filtering or query design.
- Platform-specific expectations may pressure the shared Flutter UI toward
  conditional complexity.

## Cross-Cutting Expansion Requirements

These are not early milestones, but the architecture should remain compatible
with them as the roadmap advances:

- Two-way sync adapters for issue trackers such as GitHub, GitLab, and Gitea.
- Voice assistant integrations for task capture and task updates.
- AI tool integrations for querying, creating, and modifying tasks through
  controlled backend interfaces.

Each expansion path should be implemented as adapters around the backend API
and domain layer, not as alternate sources of task semantics.
