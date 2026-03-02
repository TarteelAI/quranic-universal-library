# Best Practices

## For New Users

- Start with the mini dump, not custom data.
- Validate DB restore before debugging app code.
- Keep local setup notes (Ruby, PG port, env vars) for repeatability.

## For Contributors

- Use feature branches; avoid committing directly to `main`.
- Keep PRs focused (docs-only, migration-only, feature-only when possible).
- Write migration code to be idempotent when practical (`if_exists`, `if_not_exists`).
- If a migration touches `quran_dev`, verify state against existing dump schema.

## For Documentation

- Prefer explicit commands over abstract instructions.
- Include likely failure cases and exact fixes.
- Keep new-user path first; put advanced details after.
