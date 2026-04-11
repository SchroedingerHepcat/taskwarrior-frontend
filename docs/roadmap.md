# Roadmap

## Current milestone

Compatibility spike:

- prove a Rust task model
- prove Taskwarrior-compatible semantics direction
- define API boundaries
- scaffold the Flutter client shell

## Near-term follow-up

1. Expand the core task model around lifecycle and scheduling semantics.
2. Define how the compatibility crate maps Taskwarrior concepts into core
   types.
3. Replace server placeholders with explicit API contracts and transport
   decisions.
4. Connect the Flutter shell to a stable local development API.

## Deferred until boundaries are proven

- synchronization protocol details
- storage engine choice
- authentication and multi-user concerns
- production deployment hardening
