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

- Edit the markdown files in `app/views/docs/markdown` (source of truth). `config/docs.yml` lists the pages, their titles and their order.
- Ensure links are valid in both GitHub and website docs rendering.
- Update root `README.md` only when entrypoint links or quick-start instructions change.

## Requesting a Resource

Missing a translation, recitation or other resource? Use **Request a resource** in the site
header. Sign in to send a request, or vote for one already on the list; the requests with the
most votes are easier to plan. Each account can send a few requests a day.

## Submitting Your App

Built something with QUL data? Sign in and use **Submit your app** on the Apps page. Give its name, a
link, the platforms it runs on and the QUL resources it uses; an icon is optional. Your app appears in the directory after a QUL editor reviews it.

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
