# QUL agent guide

General setup, build commands and file locations are in
[`.github/copilot-instructions.md`](.github/copilot-instructions.md). This file covers running
the app on a local copy of the production snapshot, the test harness, and the quality gate.

## Quality gate

```bash
bin/gate                 # standalone tests, generated-types drift check, tsc, ESLint + Prettier,
                         # RSpec and Vitest; needs fresh test clones and the development clones
```

Narrow checks while working:

```bash
ruby -Itest test/path/to/file_test.rb        # standalone tests: no bundler, no database
bundle exec rspec spec/path/to/file_spec.rb  # specs: Rails on the test clones
bin/rails typelizer:check                    # generated TypeScript is current (development env)
yarn typecheck                               # tsc on app/frontend
yarn lint:frontend && yarn format:frontend   # ESLint and Prettier on app/frontend
yarn test:frontend                           # Vitest (component and SSR render tests)
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

## Inertia pages (app/frontend)

New pages are Inertia + React 19 + TypeScript, built by Vite (`vite_rails`, `config/vite.json`,
`vite.config.mts`) beside the old Sprockets, esbuild and Tailwind 3 pipeline, which is unchanged.

- Controllers inherit `InertiaController` (layout `inertia`, no Turbo). Pages live in
  `app/frontend/pages/<name>.tsx` and are rendered with `render_inertia '<name>'` (alba-inertia)
  or `render inertia:`. Props come from Alba serializers in `app/serializers`
  (`ApplicationResource`, camelCase keys); declare each attribute's type with `typelize` so the
  generated type is not `unknown`. Shared props come from `SharedPropsResource`.
- Generated files are committed: prop types in `app/frontend/types/serializers` and typed route
  helpers in `app/frontend/routes` (only the routes `config/initializers/typelizer.rb`
  includes). Regenerate with `bin/rails typelizer:generate` in development;
  `bin/rails typelizer:check` fails when they are stale. A serializer that uses
  `typelize_from <Model>` needs the database to generate; explicit `typelize` types and route
  helpers do not.
- Tailwind 4 classes are detected in `app/frontend` only. Do not put Tailwind classes in
  `app/views/layouts/inertia.html.erb`: Tailwind 3 scans `app/views`.
- The Vite configs are `.mts` because `package.json` is CommonJS (`esbuild.config.js`).
- `bin/dev` runs `bin/vite dev` beside the old processes. In development, SSR is rendered by the
  Vite dev server (`@inertiajs/vite`, endpoint `/__inertia_ssr`); without it the page renders in
  the browser. The development-only sample page is `/__dev/inertia_sample`.
- Every new page gets an SSR render test (`*.ssr.test.tsx`, node environment, helper
  `renderPageOnServer` in `app/frontend/test/inertia.tsx`): it fails when the page reads
  `window`, `document` or other browser globals during render.

Integration answers (sprint 001, story 001-02):

- Links between old and new pages are plain `<a>` links. The Inertia layout sets
  `turbo-visit-control: reload`, so a Turbo Drive visit from an old page loads the new page in
  full.
- Sign-in from a new page: link to `/users/sign_in?user_return_to=<path>`; Devise returns there.
  Sign-out: a plain form post (`_method=delete` plus the `csrf-token` meta value), not an
  Inertia visit, because Devise redirects to an old page.
- CSRF: Inertia requests send the `XSRF-TOKEN` cookie back as `X-XSRF-TOKEN`; with
  `xsrf_cookie_refresh: :lazy` the cookie is only rewritten when missing or invalid. inertia_rails
  sets that cookie on old HTML pages too.
- Meta tags: pass `meta:` to the render (title, description, canonical, Open Graph, JSON-LD
  script). They are in the HTML with and without SSR.
- Redirects: redirect with `*_path`. A path redirect stays on the request's own origin. A
  `*_url` helper uses `default_url_options` (`https`, `config/initializers/hosts.rb`), so an
  Inertia request that reached Rails as `http` gets a 409 full-page visit instead.
- JSON requests that are not page visits (the spotlight): `useHttp` from `@inertiajs/react`. It
  sends the XSRF header and does not change the URL.
- `yarn.lock` resolutions in `package.json` pin all copies of `picomatch` (2.x), `minimatch`
  (3.x) and `postcss`, including the copies Vite, Vitest and typescript-eslint ask for.
  Path-scoped resolutions crash yarn 1.22, so they are not used. The new tools work with those
  versions; typed linting with `allowDefaultProject` would not (it needs minimatch 10).

### Vite when Rails runs in Docker

`node_modules` holds macOS binaries, so Vite runs on the host and Rails in the container:

```bash
RAILS_ENV=development node_modules/.bin/vite          # host: dev server on localhost:3036
docker exec -d qul-dev socat TCP-LISTEN:3036,fork,reuseaddr,bind=127.0.0.1 TCP:host.docker.internal:3036
RAILS_ENV=test node_modules/.bin/vite build           # host: public/vite-test for request specs
docker exec -e VITE_RUBY_AUTO_BUILD=false qul-dev bundle exec rspec
```

Install `socat` in the container (`apt-get install -y socat`). The forward lets Rails reach the
dev server as `localhost:3036`, which Vite's host check accepts.

## Data safety

- Never run `db:test:prepare`, `db:schema:load`, `db:reset`, `db:drop`, `db:prepare`,
  `bin/setup` or anything that calls `maintain_test_schema!` against the snapshot.
- The snapshot's `ar_internal_metadata.environment` is `production`; leave it so.
- After `db:migrate`, commit only your own lines of `db/schema.rb`.
- Never start Sidekiq and never set SMTP variables locally.
