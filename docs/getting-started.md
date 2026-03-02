# Getting Started

This guide gets QUL running on a fresh machine with the minimum required data.

## Prerequisites

- Ruby `3.3.3` (required by `.ruby-version`)
- Node `18.x` preferred (`.node-version` is `18.0.0`)
- PostgreSQL `14.3+`
- Redis `7+`

## Quick Setup

```bash
git clone https://github.com/TarteelAI/quranic-universal-library.git
cd quranic-universal-library
```

Install Ruby gems and JS dependencies:

```bash
gem install bundler -v 2.5.15
bundle _2.5.15_ install
npm install
```

Create required databases:

```bash
createdb quran_community_tarteel
createdb quran_dev
```

Load the mini development dump into `quran_dev`:

- SQL: `https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.sql.zip`
- Binary: `https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.dump.zip`

Then run:

```bash
bundle exec rails db:migrate
bundle exec rails db:seed
```

Start the app:

```bash
bin/dev
```

Open:

- App: `http://localhost:3000`
- Admin: `http://localhost:3000/admin`

## Notes

- QUL uses two DBs:
  - `quran_dev`: Quran content data (schema: `quran`)
  - `quran_community_tarteel`: users, permissions, moderation/workflow data
- If your PostgreSQL runs on a non-default port, export `PGPORT` before running Rails commands.
