# taskwarrior-frontend

A self-hosted project-management application with Taskwarrior compatibility as
a first-class requirement.

This repository currently contains the initial scaffold for:

- a Rust workspace with core domain, compatibility, and server crates
- a minimal Flutter client shell
- early architecture, roadmap, and API boundary notes

The Rust server currently includes a transport-neutral API scaffold with
validated product-facing operations for health, create, update, status
transition, dependency updates, and query filtering. It does not yet choose a
wire protocol or implement durable storage or sync orchestration.
