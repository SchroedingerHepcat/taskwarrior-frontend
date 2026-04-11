# API Notes

## Status

No public API is implemented yet. This document records the intended boundary
so the server and Flutter app can evolve toward the same shape.

## Draft direction

- The Rust server crate will expose service-level operations.
- The Flutter client will depend on stable API contracts rather than direct
  Taskwarrior data access.
- Taskwarrior compatibility behavior should remain behind Rust boundaries,
  not in the client.

## Open questions

- transport choice
- sync model
- authentication model
- offline write reconciliation
