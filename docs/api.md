# API Notes

## Status

No transport-level API is implemented yet. This document records the currently
proven backend boundary so the server and Flutter app can evolve toward the
same shape without leaking TaskChampion internals.

## Currently Proven Backend Boundary

The Rust server crate currently demonstrates product-facing operations for:

- task creation
- task status transition
- task dependency updates
- task query and filtering by product-facing fields

The currently proven query shape uses product-level fields rather than raw
TaskChampion objects:

- statuses
- required tag
- due-before cutoff
- include-waiting flag
- reference time for waiting-state evaluation

## Boundary Rules

- The Flutter client should depend on product-facing backend operations rather
  than direct Taskwarrior or TaskChampion data access.
- Taskwarrior compatibility behavior should remain behind Rust boundaries, not
  in the client.
- The backend should not expose raw TaskChampion storage or replica objects.
- The compatibility layer may reuse TaskChampion semantics internally where
  that behavior is already authoritative.

## Open questions

- transport choice
- sync model
- authentication model
- offline write reconciliation
- pagination and list result shape
- how advanced filtering maps onto product-facing query objects
- how recurring and scheduled task queries should be represented
