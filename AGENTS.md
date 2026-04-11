# taskwarrior-frontend repository instructions

## Product goal
Build a self-hosted project-management application with Android, Linux desktop,
and web clients.  Taskwarrior compatibility is a first-class requirement, not an
import/export afterthought.  All taskwarrior features should be enabled,
including recurring tasks and scheduled tasks.

## Architectural rules
- Treat Taskwarrior 3 / TaskChampion compatibility as foundational.
- Do not design around syncing Taskwarrior data files directly.
- Do not use external file-sync approaches for task storage.
- Prefer a Rust core/domain layer that owns task semantics and compatibility.
- Prefer a Rust backend service for API and sync orchestration.
- Prefer a Flutter client for Android, web, and Linux desktop.

## taskwarrior-frontend repository instructions

## Editing rules
- Keep diffs narrow.
- Do not rename files or move directories unless the task requires it.
- Do not add dependencies without stating why.
- Do not add placeholder code that is not wired into the current design.
- Update docs when behavior or architecture changes.
- Ensure full code coverage for unit and feature level tests
- Do not remove tests unless the code that they are covering has been removed
- Treat 80 characters as the absolute maximum line length

## Quality rules
- For Rust: run formatting, linting if configured, and targeted tests first;
  then follow on with full test suite to ensure nothing was broken.
- For Flutter: run format/analyze/tests where relevant, then follow on with the
  full test suite to ensure nothing was broken.
- When creating scaffolding, make it buildable as soon as possible.
- Never claim compatibility that has not been demonstrated with code or tests.
- Nothing is done until it is fully tested and all tests pass

## Collaboration rules
- Before large changes, summarize the plan.
- After changes, summarize:
  1. what changed
  2. what remains
  3. what commands were run
  4. any open risks

## Initial milestone
The first milestone is a compatibility spike:
- prove a Rust task model
- prove Taskwarrior-compatible semantics direction
- define API boundaries
- scaffold the Flutter client shell# Editing rules
- Keep diffs narrow.
- Do not rename files or move directories unless the task requires it.
- Do not add dependencies without stating why.
- Do not add placeholder code that is not wired into the current design.
- Update docs when behavior or architecture changes.
