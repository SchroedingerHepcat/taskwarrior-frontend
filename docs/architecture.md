# Architecture

## Purpose

This repository starts with a compatibility spike, not a finished product.
The goal is to make the intended boundaries concrete while keeping the code
small enough to change quickly.

## Proposed layers

- `rust/crates/core`
  Owns task domain types and semantics.
- `rust/crates/taskwarrior_compat`
  Owns translation boundaries needed for Taskwarrior-compatible behavior.
- `rust/crates/server`
  Owns service-facing entry points and future API orchestration.
- `flutter_app`
  Owns the cross-platform client shell for Android, Linux, and web.

## Non-goals for this scaffold

- No sync protocol is defined yet.
- No persistence layer is chosen yet.
- No Taskwarrior import or export behavior is claimed yet.
- No direct file-sync architecture is introduced.

## Immediate direction

The Rust workspace is the primary executable foundation. The Flutter app is
present as a minimal shell so client work can begin without forcing API or
domain decisions too early.
