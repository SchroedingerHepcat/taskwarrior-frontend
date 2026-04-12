# taskwarrior-frontend

A self-hosted project-management application with Taskwarrior compatibility as
a first-class requirement.

This repository currently contains the initial scaffold for:

- a Rust workspace with core domain, compatibility, and server crates
- a responsive Flutter client shell with Android, Linux, and web scaffolding
- early architecture, roadmap, and API boundary notes

The Rust server currently includes a transport-neutral API scaffold with
validated product-facing operations for health, create, update, status
transition, dependency updates, and query filtering. It does not yet choose a
wire protocol or implement durable storage or sync orchestration.

The Flutter app currently includes responsive dashboard, list, board, and
detail placeholders plus a transport-tolerant backend client boundary for local
development. It does not yet use a final wire protocol or implement end-to-end
task mutations against the backend.
