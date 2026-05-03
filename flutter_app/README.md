# flutter_app

Responsive Flutter shell for the taskwarrior-frontend project.

Current scope:

- Android, Linux desktop, and web platform scaffolding
- responsive shell layouts for compact, medium, and wide screens
- dashboard, task list, board, and detail screens
- an HTTP backend client used by the application entry point
- a local development adapter retained for widget tests and local UI work

This package keeps backend access behind a client boundary so screen logic
does not depend on transport or storage details. The default app entry point
targets the Rust HTTP server. Taskwarrior and TaskChampion semantics still stay
behind Rust boundaries rather than moving into Flutter.
