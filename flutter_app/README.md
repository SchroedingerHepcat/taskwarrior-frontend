# flutter_app

Responsive Flutter shell for the taskwarrior-frontend project.

Current scope:

- Android, Linux desktop, and web platform scaffolding
- responsive shell layouts for compact, medium, and wide screens
- placeholder dashboard, task list, board, and detail screens
- a transport-tolerant backend client boundary for local development

This package does not choose a final wire protocol yet. The shell currently
uses a local development backend adapter that mirrors the backend API scaffold
without leaking TaskChampion or storage details into the UI.
