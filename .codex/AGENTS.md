# Global Codex instructions

## Working style
- I primarily edit in Vim. Do not assume an IDE workflow.
- Keep changes small and reviewable.
- Explain proposed architecture before making large structural changes.
- Prefer explicit, typed code over clever code.
- Ask before adding major production dependencies.
- After making code changes, run the narrowest relevant tests first, then broader checks if appropriate.
- Do not rewrite unrelated files.

## Output style
- Be concrete.
- When proposing commands, give copy-pasteable commands.
- When proposing file contents, give complete files when practical.
- When uncertain, say exactly what is uncertain.

## Engineering defaults
- Prefer Rust for backend/core logic.
- Prefer Flutter for cross-platform client work.
- Avoid JavaScript unless there is no reasonable alternative.
- Prefer docker-compose for first deployment unless there is a clear reason to use something heavier.
