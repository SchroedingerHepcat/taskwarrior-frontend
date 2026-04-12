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

A Rust core owns task semantics. A compatibility layer is explicitly aware of
Taskwarrior 3 and TaskChampion concepts. A Rust backend exposes an API used by
Android, Linux desktop, and web clients. Clients do not manipulate Taskwarrior
data files directly.

### Strengths

- Matches the repository rules directly.
- Keeps Taskwarrior-compatible semantics in one place.
- Gives all clients the same behavior through a backend-mediated API.
- Fits self-hosting well because the backend can own storage, sync, and policy.
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
  A backend can own storage, sync orchestration, and operational boundaries in
  a way that is understandable to one administrator.
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

The intended layer responsibilities are:

- `taskwarrior_core`
  Owns product-facing task structures and service-level operations, while
  remaining intentionally aligned with Taskwarrior-compatible semantics.
- `taskwarrior_compat`
  Owns translation to and from TaskChampion-compatible data and should reuse
  TaskChampion mutation and semantic logic where possible.
- `server`
  Owns backend-facing API operations and should expose GUI-friendly operations,
  not raw TaskChampion storage or replica objects.
- `flutter_app`
  Owns presentation and user interaction only. It must not implement
  Taskwarrior semantics itself.

## Consequences

- Frontend actions should translate into backend operations, not into direct
  client-side Taskwarrior logic.
- Backend operations should translate into TaskChampion-aware mutations through
  the compatibility layer where possible.
- Reuse of upstream TaskChampion logic is preferred over duplicating existing
  semantic behavior in this repository.
- Raw TaskChampion storage and replica objects should not leak across the API
  boundary.
- The project still needs a product-facing task model and API shape, because
  dashboards, boards, filters, and future integrations should not be forced to
  couple directly to low-level TaskChampion object shapes.

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
   The backend needs a concrete persistence and synchronization strategy that
   does not depend on external file sync and does not undermine compatibility.

## Current TaskChampion Proof Status

The following TaskChampion property mappings are currently considered proven by
code and tests in this repository:

- `description`
- `status`
- `entry`
- `modified`
- `due`
- `end`
- `wait`
- `annotation_*`
- `tag_*`
- `dep_*`
- user-defined attributes outside the known property set
- basic core status transitions for `end` and `modified`
- basic dependency mapping between product-facing tasks and TaskChampion data
- basic product-facing query filtering by status, tag, due, and waiting state

The following areas are still open and should not be treated as proven yet:

- recurring task semantics beyond preserving the `recurring` status value
- scheduled and waiting lifecycle rules beyond timestamp mapping and query
  filtering
- dependency semantics beyond basic `dep_*` mapping and storage shape
- task completion and deletion side effects beyond basic `end` timestamping
- storage, replica orchestration, and sync behavior

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
