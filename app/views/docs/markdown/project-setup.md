# Project Setup

Get the QUL application running locally so you can develop and test code changes.

> This page is a starting point. If you hit a gap, please improve it via a pull request — see [Contribution Workflow](contributing.md).

## Requirements

- Ruby `3.3.3` (see `.ruby-version`)
- PostgreSQL
- Redis (used by Sidekiq for background jobs)
- Node.js and Yarn (for asset compilation)

## Clone and Install

```bash
git clone https://github.com/TarteelAI/quranic-universal-library.git
cd quranic-universal-library
bin/setup
```

`bin/setup` installs gem and JavaScript dependencies and prepares the database.

QUL uses two Postgres databases in development (see `config/database.yml`): a CMS database (users, drafts, versions) and a separate Quran content database, `quran_dev` (verses, words, translations, and most of the app's data). `bin/setup` creates both, but `quran_dev` starts out empty — it isn't seeded by migrations. To populate it, download and load the published data dump:

```bash
curl -L -o mini_quran_dev.sql.zip https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.sql.zip
unzip mini_quran_dev.sql.zip
psql -d quran_dev -f mini_quran_dev.sql
```

Until this is loaded, pages that touch Quran content (verses, words, translations, etc.) will raise errors.

## Run the App

```bash
bin/dev
```

This boots the Rails server together with the asset watchers. The app is then available at [http://localhost:3000](http://localhost:3000), and the admin interface is built with Active Admin.

## Next Steps

- Read the [Contribution Workflow](contributing.md) before opening a pull request.
- Review the [Best Practices](best-practices.md) for keeping changes focused.
