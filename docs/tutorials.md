# Tutorials

These quick tutorials are meant for new contributors.

## 1) Run QUL Locally

1. Follow [getting-started.md](getting-started.md).
2. Confirm app opens at `http://localhost:3000`.
3. Confirm admin opens at `http://localhost:3000/admin`.

## 2) Verify Both Databases Are Connected

Run:

```bash
bundle exec rails runner 'puts ActiveRecord::Base.connection.current_database; puts Verse.connection.current_database'
```

Expected output should include:

- `quran_community_tarteel`
- `quran_dev`

## 3) Make a Safe Documentation Change

1. Create a branch:

```bash
git switch -c docs/your-topic
```

2. Edit files in `docs/`.
3. Add links in `docs/README.md` (and root `README.md` if needed).
4. Open a PR with a short summary and screenshots/output when relevant.
