<p align="center">
  <a href="https://qul.tarteel.ai">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://github.com/TarteelAI/quranic-universal-library/blob/main/.github/images/qul-og.png?raw=true">
      <img src="https://github.com/TarteelAI/quranic-universal-library/blob/main/.github/images/qul-og.png?raw=true">
    </picture>
    <h1 align="center">Quranic Universal Library (QUL)</h1>
  </a>
</p>

<p align="center">
  <a aria-label="Tarteel logo" href="https://tarteel.ai">
    <picture>
      <source height="24" media="(prefers-color-scheme: dark)" srcset="https://tarteel.ai/logo.svg">
      <img height="24" src="https://tarteel.ai/logo.svg">
    </picture>
  </a>
  <a aria-label="A project by Tarteel Shield" href="https://tarteel.ai"><img src='https://img.shields.io/badge/A%20PROJECT%20BY%20Tarteel-000000.svg?style=for-the-badge'></a>
  <a aria-label="Follow on X formerly Twitter" href="https://x.com/intent/follow?screen_name=tarteelai"><img alt="X (formerly Twitter) Follow" src="https://img.shields.io/twitter/follow/tarteelai?style=for-the-badge&logo=x"></a>
  <a aria-label="Join the community on Discord" href="https://t.zip/discord?utm_source=github&utm_medium=readme&utm_campaign=qul"><img alt="Discord" src="https://img.shields.io/discord/934719200222642186?style=for-the-badge&logo=discord&label=Join%20our%20discord"></a>
</a>
</p>

Welcome to QUL! This project is a comprehensive Content Management System designed to manage Quranic data, including translations, tafsirs, Audio, Audio segments, Arabic scripts, Mushaf layouts, and much more.

QUL is implemented using Ruby on Rails, and Active Admin for implementing the admin interface.

## Features
- Translations and Tafsirs Management: Easily add, proofread, fix issues, and export different formats.
- Audio Management: Easily add both ayah by ayah and gapless audio, manage audio segments, and export segments data.
- Arabic Scripts: Preview different Arabic scripts, both ayah by ayah and word by word.
- Mushaf Layouts: Manage different Mushaf layouts, preview them, and export them.
- User Management: Manage users, their roles, and permissions.
- Mutashabihat ul Quran: Manage Mutashabihat ul Quran data.
- Surah info: Manage Surah info data in multiple languages.
- Content Versioning: Keep track of all changes made to the content.
- Export Data: Export data in different formats.
- Import Data: Import data from different sources.
- Quranic grammar and morphology: Manage Quranic grammar and morphology data.

## Documentation
Start with the docs index: [docs/README.md](docs/README.md)

Website docs index: [https://qul.tarteel.ai/docs](https://qul.tarteel.ai/docs)

Primary path for resource users:

- Getting Started: [docs/getting-started.md](docs/getting-started.md)
- Downloading and Using Data: [docs/downloading-data.md](docs/downloading-data.md)
- Resource Guides Index: [docs/resource-guides-index.md](docs/resource-guides-index.md)
- Datasets: [docs/datasets.md](docs/datasets.md)
- Data Model: [docs/data-model.md](docs/data-model.md)
- Tutorials: [docs/tutorials.md](docs/tutorials.md)
- FAQ: [docs/faq.md](docs/faq.md)

## Contributing

Use [docs/contributing.md](docs/contributing.md) for the complete contribution flow and PR checklist.

## Production Docker image (local smoke test)

The production image is a single-process container based on `ruby:slim`. It
ships Rails behind [Thruster](https://github.com/basecamp/thruster) for HTTP/2,
X-Sendfile, and asset caching. The same image is used for the web role and the
Sidekiq worker role; they differ only in the `CMD` they run.

External services (Postgres, Redis) are expected at runtime — they are **not**
embedded in the image. Cache and Sidekiq both use Redis (`REDIS_URL`).

### Build

```bash
docker build -t qul:prod .
```

### Run web + worker + db + redis with docker-compose

```bash
cp .env.production.example .env.production   # fill in RAILS_MASTER_KEY, SMTP, S3, etc.
docker compose -f docker-compose.prod.yml up --build
```

Then open <http://localhost:8080>. Sidekiq's web UI is mounted at `/sidekiq`.

### Run by hand

```bash
# Web
docker run --rm -p 8080:80 \
  -e RAILS_MASTER_KEY=<from config/master.key> \
  -e DATABASE_URL=postgres://user:pass@host.docker.internal:5432/quran_community_tarteel \
  -e REDIS_URL=redis://host.docker.internal:6379/1 \
  --env-file .env.production \
  qul:prod

# Sidekiq worker (same image, different CMD)
docker run --rm \
  --env-file .env.production \
  qul:prod ./bin/start-sidekiq
```

### Notes

- `bundle install` (locally) is required after pulling in the new `thruster`
  gem so that `Gemfile.lock` is regenerated before you build.
- Secrets are passed at **runtime** via `--env-file` / `-e`. They are no longer
  baked into the image as `ARG`/`ENV`.
- Building on Apple Silicon: add `--platform=linux/amd64` if your production
  target is amd64.

