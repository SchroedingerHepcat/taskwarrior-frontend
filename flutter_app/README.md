# flutter_app

Responsive Flutter shell for the taskwarrior-frontend project.

Current scope:

- Android, Linux desktop, and web platform scaffolding
- responsive shell layouts for compact, medium, and wide screens
- dashboard, task list, board, and detail screens
- frontend controls for backend-owned task list filtering, including
  dropdown metadata filters, no-metadata choices, and date ranges
- saved task views with local persistence, JSON import/export, and backend
  push/pull sharing
- dashboard layouts with fixed widgets, saved-view-backed panels, local
  persistence, naming, ordering, JSON import/export, and backend push/pull
  sharing
- recurrence controls for existing tasks that submit Taskwarrior-compatible
  properties without creating recurrence child tasks in Flutter
- an HTTP backend client used by the application entry point
- a local development adapter retained for widget tests and local UI work

This package keeps backend access behind a client boundary so screen logic
does not depend on transport or storage details. The default app entry point
targets the Rust HTTP server. Taskwarrior and TaskChampion semantics still stay
behind Rust boundaries rather than moving into Flutter.
