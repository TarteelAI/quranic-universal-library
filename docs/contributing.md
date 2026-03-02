# Contributing

## Basic Flow

1. Fork repository on GitHub.
2. Clone your fork.
3. Add upstream remote:

```bash
git remote add upstream https://github.com/TarteelAI/quranic-universal-library.git
```

4. Create branch:

```bash
git switch -c docs/your-change
```

5. Make changes, commit, push, open PR to `TarteelAI/quranic-universal-library`.

## Keep Your Fork Updated

```bash
git fetch upstream
git switch main
git merge upstream/main
git push origin main
```

## Documentation PR Checklist

- Docs are clear for first-time users.
- All commands are copy-paste ready.
- Root `README.md` links to any new docs page.
- Spelling and link checks are done.
