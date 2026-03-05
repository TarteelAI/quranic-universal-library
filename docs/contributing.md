# Contributing

Thanks for helping improve QUL.

## Where to Contribute

- Repository: [https://github.com/TarteelAI/quranic-universal-library](https://github.com/TarteelAI/quranic-universal-library)
- Issues: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Standard Flow

1. Fork the repository.
2. Clone your fork.
3. Add upstream remote.
4. Create a feature branch.
5. Make focused changes.
6. Push branch and open PR.

```bash
git clone https://github.com/YOUR-USERNAME/quranic-universal-library.git
cd quranic-universal-library
git remote add upstream https://github.com/TarteelAI/quranic-universal-library.git
git switch -c docs/your-topic
```

## Documentation Contributions

- Edit files in `docs/` first (source of truth).
- Ensure links are valid in both GitHub and website docs rendering.
- Update root `README.md` only when entrypoint links or quick-start instructions change.

## Reporting Data Issues

When opening an issue for dataset problems, include:

- Dataset URL and format (JSON/SQLite)
- Exact identifiers (`surah_id`, `ayah_number`, `word_position` when relevant)
- Expected vs actual output
- Minimal reproducible snippet

## PR Checklist

- Scope is clear and focused.
- Commands in docs were re-validated.
- New user onboarding path remains intact.
- Backward-compatible website docs behavior is preserved.
