# Architecture

## Goal

This project needs one architecture that can support:

- self-hosted deployment
- Android, Linux desktop, and web clients
- Taskwarrior-compatible behavior
- long-term maintenance without splitting task semantics across clients

This document compares three plausible directions and recommends one.

## Option 1: Direct Taskwarrior Data Or File-Based Compatibility

### Description

Clients read and write Taskwarrior data or TaskChampion-managed data directly,
or they depend on file-oriented storage as the primary integration boundary.
Each client is responsible for enough Taskwarrior behavior to operate against
that storage.

### Strengths

- Closest to existing Taskwarrior storage conventions.
- May simplify migration for users who already think in terms of local task
  data files.
- Can look attractive for single-user Linux setups.

### Weaknesses

- It conflicts with the repository rule to avoid designing around syncing
  Taskwarrior data files directly.
- Android and web clients are a poor fit for file-based coordination.
- File ownership, locking, and conflict handling become part of each client.
- Task semantics would leak into multiple clients instead of one Rust layer.
- Browser clients cannot rely on direct filesystem access in any coherent way.
- Self-hosted deployment becomes harder because the application boundary is
  unclear: is the source of truth a backend, a shared filesystem, or both?

### Risk Assessment

- High risk of semantic drift between clients.
- High risk of data corruption or unexpected conflicts if multiple clients
  touch the same underlying data independently.
- High risk of platform-specific behavior, especially on Android and web.
- High risk that "compatibility" is interpreted as storage compatibility
  rather than behavioral compatibility.

### Fit For Project Goals

- Self-hosting: weak
- Android client: poor
- Linux desktop client: acceptable for narrow local cases, weak overall
- Web client: poor
- Taskwarrior compatibility: partial at storage level, weak at product level
- Long-term maintainability: poor

## Option 2: TaskChampion-Aware Rust Core With Backend-Mediated API

### Description

A Rust core owns product-facing task structures and API-facing semantics. A
compatibility layer is explicitly aware of Taskwarrior 3 and TaskChampion
concepts. A Rust backend exposes an API used by Android, Linux desktop, and
web clients, and it performs task CRUD through Taskwarrior or TaskChampion.
Clients do not manipulate Taskwarrior data files directly.

For multi-device synchronization, the backend should act as a TaskChampion
replica client. It should be configurable to synchronize with a separate
self-hosted TaskChampion sync server, such as the upstream
`ghcr.io/gothenburgbitfactory/taskchampion-sync-server` container. This project
provides the frontend and product API for that data; it should not replace the
TaskChampion sync server role.

### Strengths

- Matches the repository rules directly.
- Keeps Taskwarrior-compatible semantics in one place.
- Gives all clients the same behavior through a backend-mediated API.
- Fits self-hosting well because the backend can own storage access, sync
  orchestration, and policy while Taskwarrior or TaskChampion remain the task
  storage authority.
- Fits deployments where a user already runs a TaskChampion sync server,
  because this backend can become another TaskChampion replica rather than a
  replacement sync service.
- Makes Android and web support realistic because clients can stay thin.
- Preserves a path to strong compatibility without forcing the UI layer to
  understand Taskwarrior internals.

### Weaknesses

- More initial backend work than a file-based prototype.
- Requires careful definition of the boundary between the core domain and the
  Taskwarrior compatibility layer.
- Some Taskwarrior features may not map cleanly without deeper TaskChampion
  investigation.

### Risk Assessment

- Medium risk that TaskChampion assumptions are incomplete or wrong.
- Medium risk that the backend API is designed too early and bakes in gaps in
  recurring task or scheduling semantics.
- Medium risk that compatibility translation becomes complex if the core model
  diverges from Taskwarrior concepts too quickly.
- Medium risk that a generic storage abstraction could accidentally recreate a
  custom task database instead of routing CRUD through Taskwarrior or
  TaskChampion.

### Fit For Project Goals

- Self-hosting: strong
- Android client: strong
- Linux desktop client: strong
- Web client: strong
- Taskwarrior compatibility: strong candidate, if proven with tests
- Long-term maintainability: strong

## Option 3: Backend-Owned Custom Task Model With Import/Export Only

### Description

The backend owns a custom task model and treats Taskwarrior only as an import
and export format. Compatibility is limited to data exchange, not shared
semantics.

### Strengths

- Simplifies product-specific modeling choices.
- Can reduce short-term friction if the team wants to ignore Taskwarrior
  semantics early.
- May allow faster implementation of app-specific features that do not map to
  Taskwarrior.

### Weaknesses

- It conflicts with the project requirement that Taskwarrior compatibility is
  first-class rather than an import/export afterthought.
- Compatibility would be fragile because behavior would not be modeled around
  Taskwarrior semantics from the start.
- Import/export-only support tends to fail on recurring tasks, scheduled
  tasks, metadata fidelity, and sync expectations.
- Migration from this model toward real compatibility would be expensive.

### Risk Assessment

- High risk of building the wrong product for the stated goal.
- High risk of irreversible model drift away from Taskwarrior.
- High risk that future compatibility work becomes a rewrite instead of an
  extension.

### Fit For Project Goals

- Self-hosting: strong
- Android client: strong
- Linux desktop client: strong
- Web client: strong
- Taskwarrior compatibility: weak
- Long-term maintainability: mixed, strong only if compatibility is dropped

## Recommendation

Recommend option 2: a TaskChampion-aware Rust core with a backend-mediated
API.

This is the only option that aligns with all stated constraints at once.
Option 1 fails the multi-client and self-hosted architecture requirements
because it pushes storage and semantic coordination into the clients. Option 3
can produce a clean backend, but it fails the compatibility requirement by
making Taskwarrior support secondary.

Option 2 is the best fit for each target:

- Self-hosting
  A backend can own API, sync orchestration, and operational boundaries while
  storing tasks through Taskwarrior 3 and TaskChampion directly.
- Android client
  Android should not depend on direct file-level compatibility or local
  synchronization tricks. An API boundary is the practical approach.
- Linux desktop client
  Linux can support richer local workflows, but it still benefits from the
  same semantics and backend contract as the other clients.
- Web client
  Web support strongly favors a backend-owned source of truth and a stable API.
- Taskwarrior compatibility
  A dedicated Rust compatibility layer provides one place to prove semantics,
  rather than copying partial behavior into every client.
- Long-term maintainability
  One semantic core is cheaper to evolve and test than multiple client-side
  interpretations of Taskwarrior behavior.

## Layer Decision

The working decision is to reuse existing TaskChampion and
Taskwarrior-compatible logic where it already provides the semantic authority,
instead of casually reimplementing that logic in this repository.

That decision does not mean raw TaskChampion objects become the application
model across all layers.

Taskwarrior 3 and TaskChampion are also the intended durable task storage and
mutation authority. The server should interface with Taskwarrior or
TaskChampion for all task CRUD events rather than persisting an independent
custom task store. Product-facing server operations should translate into
Taskwarrior-compatible mutations, then read back through the same compatibility
boundary.

The intended sync topology is:

- Flutter clients call this project's backend HTTP API.
- This project's backend owns filtering, dashboard, board, and validation
  behavior for the UI.
- The backend stores tasks as a TaskChampion replica.
- The backend may synchronize that replica with an external TaskChampion sync
  server.
- The external TaskChampion sync server remains the sync coordination service.
- When sync is configured, backend task reads should pull from the
  TaskChampion sync server before serving product queries, and task writes
  should push through TaskChampion sync after local TaskChampion mutation.

The intended layer responsibilities are:

- `taskwarrior_core`
  Owns product-facing task structures and service-level operations, while
  remaining intentionally aligned with Taskwarrior-compatible semantics.
- `taskwarrior_compat`
  Owns translation to and from TaskChampion-compatible data, and owns the
  integration path used by the server to perform Taskwarrior-compatible CRUD.
  It should reuse TaskChampion mutation and semantic logic where possible.
- `server`
  Owns backend-facing API operations and should expose GUI-friendly operations.
  It should route task CRUD through Taskwarrior or TaskChampion via the
  compatibility layer, not expose raw TaskChampion storage or replica objects.
  It should also own configuration for connecting its TaskChampion replica to
  an external TaskChampion sync server. Backend configuration may come from a
  file, environment variables, or CLI flags, but those settings remain server
  setup concerns rather than Flutter API fields.
- `flutter_app`
  Owns presentation and user interaction only. It must not implement
  Taskwarrior semantics itself.

## Consequences

- Frontend actions should translate into backend operations, not into direct
  client-side Taskwarrior logic.
- Backend task CRUD operations should translate into Taskwarrior or
  TaskChampion mutations through the compatibility layer.
- Reuse of upstream TaskChampion logic is preferred over duplicating existing
  semantic behavior in this repository.
- The backend should not maintain a separate authoritative task database with
  Taskwarrior treated as a secondary import or export target.
- Raw TaskChampion storage and replica objects should not leak across the API
  boundary.
- Direct synchronization of Taskwarrior data files remains a rejected
  architecture. TaskChampion-backed storage is used through Rust APIs and
  controlled backend operations, not through client-visible file sharing.
- A separate TaskChampion sync server is compatible with the architecture and
  is the preferred external sync coordination service for first-party task
  data. This project should integrate with it rather than replace it.
- The project still needs a product-facing task model and API shape, because
  dashboards, boards, filters, and future integrations should not be forced to
  couple directly to low-level TaskChampion object shapes.
- Saved views are product-facing query configuration, not task storage. They
  may be stored locally in Flutter for client restart behavior and shared
  through backend endpoints for cross-client reuse, but they must not become an
  independent task database or expose TaskChampion internals.
- Dashboard layouts are product-facing presentation and query configuration,
  not task storage. They may reference fixed backend query widgets and saved
  task views, and they may be stored locally or shared through backend
  endpoints, but task data must still come through backend task queries.
- Backend-shared saved views and dashboard layouts are durable UI
  configuration, not task storage. Persisting them outside TaskChampion is
  acceptable because they do not mutate or replace Taskwarrior-compatible task
  data.
- Recurrence instance creation is owned by Taskwarrior or TaskChampion
  semantics. This application should expose recurring tasks, allow users to
  create recurrence settings on existing tasks, and allow users to modify
  recurrence options. The client and this project's backend must not spawn
  future recurring task instances themselves.
- The product interface should eventually expose every recurrence schedule
  option supported by Taskwarrior, but the app should still store and submit
  those options through Taskwarrior-compatible recurrence properties rather
  than inventing a separate recurrence engine.

## What Still Needs Proof

The recommendation is directional, not proven. The following items still need
evidence:

1. Core model proof
   The Rust core must show it can represent Taskwarrior-relevant concepts
   without immediately collapsing into a thin copy of storage-layer details.
2. Compatibility proof
   The compatibility layer must demonstrate recurring tasks, scheduled tasks,
   status transitions, and metadata round-tripping with automated tests.
3. TaskChampion boundary proof
   The project must confirm exactly which TaskChampion concepts are reused as
   semantic authority and which remain product-layer translation concerns.
4. API boundary proof
   The server API must be validated against real client needs so that it does
   not expose storage details or omit necessary semantic operations.
5. Storage and sync proof
   The backend must prove concrete Taskwarrior or TaskChampion-backed storage
   and synchronization through Rust APIs, without external file sync or an
   independent custom task store.
6. External sync-server proof
   The backend must prove that its TaskChampion replica can synchronize with a
   separately hosted TaskChampion sync server without exposing that sync
   protocol to Flutter clients.

## Current TaskChampion Proof Status

The following TaskChampion property mappings are currently considered proven by
code and tests in this repository:

- `description`
- `status`
- `entry`
- `modified`
- `due`
- `scheduled`
- `project`
- `end`
- `wait`
- `recur`
- `rtype`
- `until`
- `parent`
- `mask`
- `imask`
- `annotation_*`
- `tag_*`
- `dep_*`
- user-defined attributes outside the known property set
- basic core status transitions for `end` and `modified`
- basic dependency mapping between product-facing tasks and TaskChampion data
- basic product-facing query filtering by status, tag, no-tags, due,
  scheduled, and waiting ranges
- GTD-shaped saved query presets for inbox, next actions, waiting, and review
- product-facing filtering for project, no-project, waiting, scheduled, and
  blocked task state
- product-facing sorting by due, modified, and description at the server
  boundary
- board lane transitions for pending, waiting, and completed lanes
- an HTTP backend path for create, get, update, transition, and query
  operations
- request validation at the backend boundary for descriptions, project input,
  tags, annotations, status input, dependency shape, and query shape
- internal server boundaries for TaskChampion-backed repository storage and
  sync coordination
- server CRUD backed by a TaskChampion `Replica` using TaskChampion storage
- backend storage configuration for in-memory test storage and SQLite-backed
  TaskChampion storage
- backend sync configuration for disabled sync, local TaskChampion sync-server
  tests, and remote sync-server connection details
- local TaskChampion sync proof moving a task between two backend replicas
  through TaskChampion sync APIs
- HTTP task writes syncing to a TaskChampion server and HTTP task reads
  pulling from that server before serving product-facing queries
- a Flutter shell boundary that routes user navigation and screen state through
  product-facing client operations rather than Taskwarrior storage concepts
- full end-to-end create, update, complete, and query flows from Flutter to the
  Rust backend over HTTP
- a frontend advanced filter panel that sends product-facing query fields,
  including project, no-project, tag, no-tags, and date ranges, to the backend
  instead of reimplementing Taskwarrior filtering in Flutter
- local saved task views with create, edit, select, delete, import, export,
  and backend push/pull behavior based on product-facing query definitions
- local dashboard layout configuration with fixed widgets, saved-view-backed
  panels, import/export, local persistence, and backend push/pull behavior
- backend restart persistence for shared saved views and dashboard layouts
  through a durable UI state file
- an architectural decision to support an external TaskChampion sync server as
  the first-party task sync coordinator

The following areas are still open and should not be treated as proven yet:

- recurrence creation and editing UI for every Taskwarrior-supported schedule
  option
- proof that Taskwarrior or TaskChampion creates recurrence child tasks through
  their own semantics after this app sets recurrence properties
- scheduled and waiting lifecycle behavior beyond timestamp mapping and
  backend query filtering
- dependency semantics beyond basic `dep_*` mapping, storage shape, and
  unresolved-dependency filtering
- production deployment of durable TaskChampion storage, including migration,
  backup, and operational checks
- sync conflict behavior, retry behavior, and user-facing sync state
- tests for syncing the backend replica with an external remote TaskChampion
  sync server
- whether additional protocols are needed beyond the current HTTP boundary
- task completion and deletion side effects beyond basic `end` timestamping
  and dependency unblocking in query presets
- replica orchestration beyond the first local TaskChampion sync proof

## Main Risks In The Recommended Architecture

- The team may underestimate Taskwarrior semantic complexity and design a core
  model that is too simple.
- The compatibility layer may become a dumping ground unless the core and
  compatibility boundaries are kept explicit.
- A backend-first architecture can still fail if the API is defined before the
  semantic model is mature enough.
- There is still a risk that TaskChampion-aware design choices turn out to be
  insufficient for full Taskwarrior 3 behavior.

## Decision

Use a Rust core plus Taskwarrior compatibility layer plus backend-mediated API
as the working architecture for the compatibility spike. Treat file-based
integration as a rejected primary architecture. Treat import/export-only
compatibility as incompatible with the project goal.
