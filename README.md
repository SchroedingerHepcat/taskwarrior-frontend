# taskwarrior-frontend

A self-hosted project-management application with Taskwarrior compatibility as
a first-class requirement.

This repository currently contains the initial scaffold for:

- a Rust workspace with core domain, compatibility, and server crates
- a responsive Flutter client shell with Android, Linux, and web scaffolding
- architecture, roadmap, and API boundary notes aligned to the current build

The Rust server currently includes a small HTTP API with validated
product-facing operations for health, create, get, update, status transition,
and query filtering. It does not yet implement durable storage, authentication,
or sync orchestration. The intended durable task storage path is through
Taskwarrior 3 and TaskChampion, not a separate custom task database.

The Flutter app currently includes responsive dashboard, list, board, and
detail screens backed by that HTTP API. It now proves end-to-end create,
update, complete, and filtered list flows against the Rust backend, while
later milestones still own recurrence, advanced filtering, deployment, and
sync.
