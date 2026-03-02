# FAQ

## Do I need the full production database?

No. Use the official **mini development dump**. Full production dump is not shared.

## Should I use SQL or binary dump?

Start with binary. If your `pg_restore` client cannot read it, use SQL dump.

## Why do I see migration conflicts like duplicate columns/tables?

The dump can already contain schema changes that also exist as migrations. Validate actual schema state before applying destructive fixes.

## Which PostgreSQL version should I use?

PostgreSQL `14.3+` is supported. If multiple versions are installed locally, set `PGPORT` (and optionally `PGHOST`) explicitly.

## I run `bin/dev` and it fails with `foreman` missing.

Install foreman in the active Ruby:

```bash
gem install foreman
```

## App boots but some pages fail

Check:

1. Mini dump restore completed without errors.
2. `rails db:migrate` and `rails db:seed` finished.
3. Redis and PostgreSQL are running.
