# QUL agent guide

General setup, build commands and file locations are in
[`.github/copilot-instructions.md`](.github/copilot-instructions.md). This file covers running
the app on a local copy of the production snapshot, the test harness, and the quality gate.

## Quality gate

```bash
bin/gate                 # standalone tests (test/) + RSpec (spec/); needs fresh test clones
```

Narrow checks while working:

```bash
ruby -Itest test/path/to/file_test.rb        # standalone tests: no bundler, no database
bundle exec rspec spec/path/to/file_spec.rb  # specs: Rails on the test clones
```

- `test/` is loaded without bundler or a database by CI (`.github/workflows/tests.yml`).
  Nothing that boots Rails goes under `test/`.
- `spec/` boots Rails through `spec/clone_helper.rb` (`require 'clone_helper'`). It never loads,
  checks or migrates the schema, and aborts unless both databases are snapshot clones. Do not
  add a `spec/rails_helper.rb` that calls `maintain_test_schema!`.

## Running on the snapshot

The snapshot is two Postgres databases restored from a production backup (connection details
and restore steps are in the private sprint notes). Nothing runs against the snapshot itself:
development and test each use their own clones, made with `CREATE DATABASE … TEMPLATE`.

1. Ruby inside the Gemfile range (3.3.3 to 3.3.10; Docker uses 3.3.10), Node 24.19.0
   (`.node-version`), yarn classic.
2. `bundle install`, then `yarn install` and `yarn build && yarn build:css` (the old pages need
   `app/assets/builds`).
3. Connection variables (both files are gitignored; `config/database.yml` reads them):
   - `.env` for development: `QUL_CMS_CONTENT_DB_*` and `QUL_QURAN_CONTENT_DB_*` (host, port,
     username, password) pointing at the snapshot server, plus
     `CDN_HOST=https://static-cdn.tarteel.ai` (font URLs are relative without it).
   - `.env.test.local` for test: the same with `_TEST_` (`QUL_CMS_CONTENT_TEST_DB_PORT`, …).
     dotenv loads nothing in test; `spec/clone_helper.rb` and `bin/snapshot-clones` load this
     file.
   - Leave the database names at their defaults (`qul_cms_content_dev`, `qul_quran_content_dev`,
     `qul_cms_content_test`, `qul_quran_content_test`). The snapshot names are
     `QUL_SNAPSHOT_CMS_DB_NAME` and `QUL_SNAPSHOT_QURAN_DB_NAME` (defaults `qul_cms`,
     `qul_quran`).
4. Make the clones. Each run drops and remakes them, so remake after any migration change:
   ```bash
   bin/snapshot-clones               # test clones
   bin/snapshot-clones development   # development clones (drops local dev data)
   ```
   It refuses a target named like a snapshot database, marks each clone with a database
   comment (`SnapshotClone`), and applies the CMS migrations the snapshot lacks without
   dumping `db/schema.rb`. A copy fails while another session is connected to the snapshot.
5. `bin/rails dev:fake_accounts` creates `reader@example.test` and `admin@example.test`
   (password in `lib/fake_accounts.rb`) in the development clone. It refuses in production and
   on any database without the clone marker.
6. `bin/rails server`, then use `http://localhost:3000` (never `127.0.0.1`; see
   `config/initializers/hosts.rb`). Request specs call `host! 'localhost'` for the same reason.

What to expect:

- **Redis is not needed to serve pages.** `/`, `/resources` and the type and detail pages
  render without it. Anything that enqueues a job fails without Redis, because ActiveJob uses
  Sidekiq outside test: sign-up (welcome email), resource update emails, API client
  registration and admin todo emails. The test environment uses the `:test` adapter.
- **Rails needs a JavaScript runtime to boot** (ExecJS). Node is enough.
- `escompress` minifies inline scripts with esbuild while rendering. When esbuild cannot run,
  it logs an error and the page still renders.

### Running in Docker instead

When no Ruby in the Gemfile range is installed, run Rails in the Ruby image Docker uses, with
the checkout mounted and gems in a volume. Build JS and Sass on the host
(`node_modules` holds host binaries).

```bash
H=host.docker.internal   # the snapshot server as seen from the container
docker run -d --name qul-dev -v "$PWD":/app -v qul-dev-bundle:/usr/local/bundle -w /app -p 3000:3000 \
  -e QUL_CMS_CONTENT_DB_HOST=$H -e QUL_QURAN_CONTENT_DB_HOST=$H \
  -e QUL_CMS_CONTENT_TEST_DB_HOST=$H -e QUL_QURAN_CONTENT_TEST_DB_HOST=$H \
  ruby:3.3.10-bookworm sleep infinity
docker exec qul-dev bash -c 'apt-get update && apt-get install -y libhunspell-dev nodejs && gem install bundler:2.5.15 && bundle install'
docker exec qul-dev bin/snapshot-clones
docker exec qul-dev bundle exec rspec
docker exec qul-dev bin/rails server -b 0.0.0.0 -p 3000
```

`Gemfile.lock` has no Linux platform, so `bin/rails tailwindcss:build` finds no binary there.
Install the platform gem inside the container only
(`gem install tailwindcss-rails -v 2.7.5 --platform aarch64-linux --ignore-dependencies`) and
run its `exe/aarch64-linux/tailwindcss -i app/assets/stylesheets/application.tailwind.css
-o app/assets/builds/tailwind.css -c config/tailwind.config.js --minify`. Do not add platforms
to the lockfile.

## Data safety

- Never run `db:test:prepare`, `db:schema:load`, `db:reset`, `db:drop`, `db:prepare`,
  `bin/setup` or anything that calls `maintain_test_schema!` against the snapshot.
- The snapshot's `ar_internal_metadata.environment` is `production`; leave it so.
- After `db:migrate`, commit only your own lines of `db/schema.rb`.
- Never start Sidekiq and never set SMTP variables locally.
