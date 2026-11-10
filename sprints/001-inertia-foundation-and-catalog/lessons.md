# Lessons - 001-inertia-foundation-and-catalog

> High-signal knowledge for future work in this sprint. Story-local context belongs in `spec.json` `notes`, not here.
> Only add entries that would help future work avoid a problem or rediscovery — durable, non-obvious, and not already in `notes` / code / architecture decisions / docs.

## Planning Context

Paths that start with `../` are sibling folders on the team's machines. They are local to the team and are never committed. Facts below were checked on 2026-11-09 against main `30bec50e` and a local snapshot dated 2026-11-02.

**Main moved after these facts were checked.** `qul-next` is cut from main `3d805f64`, which is 24 commits past `30bec50e`. Those commits rewrote `config/database.yml` (and added `config/database.yml.example`), changed `config/routes.rb`, `db/schema.rb`, `bin/setup` and the Docker dev database script, added contributor tools with new draft tables and migrations, replaced the GitHub issue templates with issue forms, and changed how SQLite exports replace rows. The facts below about `config/database.yml`, the content-record class, the issue forms and the workflows were re-checked at `3d805f64` and corrected in place. Treat any fact about `config/routes.rb`, `db/schema.rb`, `bin/setup` and the SQLite exports as unverified until 001-01 has re-checked it (`git diff 30bec50e 3d805f64 -- <path>`), and correct this file in the Gotchas section when one is wrong.

**Local `main` can be behind `origin/main`.** Compare against `origin/main` or `git merge-base origin/main HEAD`, never the local `main` branch.

### Working rules

- **This repo is public.** Everything committed here is public: code, `spec.json` handoffs, entries in this file, `VALIDATION.md`. Do not write down anything from user, download, draft or admin tables, any credential or connection string, or any description of a weakness in the running site. Describe the behaviour the new code has. Sensitive context is in the private sprint notes (team drop); refer to them, do not quote them.
- **Branches.** Sprint work is on `sprint/001-inertia-foundation-and-catalog`, cut from `qul-next`, which is cut from `main`. Never commit on `main`. Never push, open a PR or run `gh` write commands until a human says go. `git fetch` is fine.
- **Commits.** One commit per story, with the story id in the subject (`[001-08] …`), holding the code, `spec.json` and any regenerated types together.
- **Issue forms and workflows.** `.github/ISSUE_TEMPLATE` holds YAML issue forms: one `content_issue.yml` for every resource type (it has a `resource_type` dropdown) and a `resource_request.yml`; there is no app-submission form yet. `.github/workflows` has four files (`tests.yml`, `deploy.yml`, `codeql.yml`, `issue-triage.yml`); `tests.yml` runs on every pull request.
- **Gate.** One command, defined by 001-01 and extended by 001-02 and 001-05, recorded in `AGENTS.md` and `.agents/config.yaml`. It runs: the generated-types drift check, `tsc`, ESLint and Prettier on `app/frontend`, RSpec, Vitest. Playwright is a separate command that stories with browser criteria run. 001-06 adds a CI workflow for the checks that need no database; RSpec and Playwright run only locally. The existing `tests.yml` loads every `test/**/*_test.rb` without bundler or a database, so nothing that boots Rails may go under `test/`.
- **Small diffs in shared files.** The unmerged `origin/qiraat/*` stack edits `app/models/downloadable_resource.rb` (adds two resource types and scopes), `config/routes.rb` (a new `internal` namespace near the top and the proofreading routes), `Gemfile` (the rspec test group), `config/database.yml` (the development database name and a test entry), `app/views/resources/previews/_font.html.erb` and `_quran_script.html.erb`, `app/views/shared/_mushaf_page` and `_page_font`, and `db/schema.rb` (version line). In those files: one `include` line, one routes block, the exact same Gemfile lines. Do not edit the preview partials at all.
- **Old code stays.** Do not edit or delete the old views, `ResourcesController`, `ResourcePresenter`, `application.html.erb`, `app/javascript`, `esbuild.config.js` or `config/tailwind.config.js`. New pages are new files behind the page group setting. The one exception is the old download URL: 001-10 sends it to the new download controller from the sprint's routes block, without editing `ResourcesController`.
- **No constitution yet.** Until `ralph-init` runs, treat these as protected surfaces (never `low`, always reviewed): migrations and backfills, the download route, auth and session handling, the Dockerfile and `docker/` service files.

### Running Rails locally

- The connection details for the snapshot, the restore steps and the data-safety background are in the private sprint notes.
- Ruby must be inside the Gemfile range (3.3.3 to 3.3.10); Docker uses 3.3.10 and `.ruby-version` is 3.3.5. `.node-version` is 24.19.0. The package manager is yarn classic (`yarn.lock`); a stray `bun.lock` exists, leave it alone. `pg`, `sassc`, `cld3` and `ffi-hunspell` compile native code on `bundle install`.
- The CMS database and the Quran content database are two separate Postgres databases, not two schemas. SQL cannot join across them. Preload in two steps. `ApplicationRecord` is the CMS side; `QulQuranRecord` is the content side and picks its connection by environment (`qul_quran_content_db_dev` in development, `qul_quran_content_db_test` in test, `qul_quran_content_db` otherwise).
- `config/database.yml` reads every database name, host and credential from `QUL_QURAN_CONTENT_*` and `QUL_CMS_CONTENT_*` variables, with local defaults in development and test (`qul_quran_content_dev`, `qul_cms_content_dev`, `qul_quran_content_test`, `qul_cms_content_test`). The sprint does not need to edit it.
- The CMS schema enables no Postgres extension beyond `plpgsql`: no `unaccent`, no `pg_trgm`.
- A public mini dump of the content database exists (see `app/views/docs/markdown/project-setup.md`). It is smaller than the snapshot.
- Set `CDN_HOST=https://static-cdn.tarteel.ai` or font URLs come out relative. It is not in `.env.sample`.
- Use `localhost`, never `127.0.0.1` (`config/initializers/hosts.rb`).
- `dotenv` loads `.env` in development only, not in test.
- Redis is not needed to serve requests. Never start Sidekiq and never set SMTP variables.
- **Never run against the snapshot:** `db:test:prepare`, `db:schema:load`, `db:reset`, `db:drop`, or anything that calls `maintain_test_schema!`. The snapshot's `ar_internal_metadata.environment` is `production`; `db:migrate` in development rewrites it and removes the guard on destructive tasks, so the rule is the only guard.
- Tests run on clones made with `CREATE DATABASE … TEMPLATE …`, remade after every migration or backfill change. A template copy fails while another session is connected to the source.
- After `db:migrate`, check `git diff db/schema.rb` and commit only your own lines. `db/schema.rb` is the CMS schema only. New migrations use the CMS connection only; older migrations that call `Word.connection` are the pattern to avoid. The content database is never changed.
- The test and development cache stores keep nothing (`null_store`), and production uses memcached. Do not build behaviour that needs the cache to be correct.
- Existing file blobs resolve to the `qul_exports` storage service. Without the storage variables, a file URL points at a wrong host locally. Assert redirects, not file fetches.

### Build and deploy traps

- The Dockerfile sets `NODE_ENV=production` before `yarn install --frozen-lockfile`, so devDependencies are not installed in the image. Build tools are regular dependencies; test and lint tools are devDependencies.
- `assets:precompile` runs twice in the Dockerfile (a known workaround) and already chains jsbundling (`yarn install` and `yarn build`), cssbundling and Tailwind. `vite_ruby` adds `vite:build_all` and its own install to the same task.
- The package.json `build` script belongs to esbuild and jsbundling calls it. Do not change it for Vite or SSR.
- esbuild owns `app/javascript` and writes to `app/assets/builds`. `vite install` uses `app/javascript` when it exists unless `sourceCodeDir` is set first.
- The Inertia generator and `vite install` inject tags into `application.html.erb`, which every old page uses, and may overwrite `bin/dev`.
- nginx (`docker/qul.tarteel.ai`) gives one-year expiry and `gzip_static` only to `/assets/`. It sets `Host` and `X-Forwarded-For` but not `X-Forwarded-Proto`; inertia-rails compares origins to decide whether a redirect is external.
- The image is `phusion/passenger-customizable` with runit services: nginx and Passenger, redis, memcached and Sidekiq (`docker/sidekiq.run`). There is no Puma, so the Puma SSR plugin does not apply.
- The image starts Sidekiq by default. Any local run of the image disables that service before start.
- `deploy.yml` builds and deploys on every push to `main`. That is one more reason nothing goes to `main`.
- `.dockerignore` does not exclude `sprints/`.
- `/docs/` is gitignored at the repo root.
- `production.rb` turns eager loading off when `SECRET_KEY_BASE_DUMMY` is set; `assets.compile` is false; there is no `asset_host`.

### What the old pages do that new pages must keep

- Meta tags come from `SeoHelper` and `ApplicationPresenter#meta_tags`: title, description, robots, Open Graph, Twitter, a canonical link with the host hardcoded to the production host, and JSON-LD. There is no meta-tags gem and no sitemap.
- `shared/_meta_tags.html.erb` also loads the Sentry browser loader, GA4 (page views fire on `turbo:load` and `turbo:frame-load`, which never fire on an Inertia page), Google Fonts and Font Awesome.
- Turbo Drive is on everywhere, with `data-turbo-track="reload"` on assets and a `data-turbo-permanent` header.
- Flash goes through a hidden div and a Stimulus controller on old pages.
- `protect_from_forgery with: :exception` is set. Every layout calls `csrf_meta_tags`.
- Devise 5 with `sign_out_via :delete`. Sign-in pages use the `devise` layout and stay ERB. The old landing page also uses the `devise` layout.
- `ApplicationController` has many `rescue_from` handlers and a `render_error` that renders a 404 outside development. An unknown resource under `/resources/…` currently raises instead of returning 404; the new pages return 404.
- The old route table: `/resources/:id` is the type page (the type is `:id`), `/resources/:type/:id` is the detail page, and `/resources/:type/:id/:tab` exists for four tab names. `/search` is Quran text search, not catalog search.
- No dark mode, no CSP header, no i18n calls in public views.

### Inertia facts that are easy to get wrong

- Inertia v3 clients need React 19 and three server options (`use_script_element_for_initial_page`, `use_data_inertia_head_attribute`, `always_include_errors_hash`), and `config.version = ViteRuby.digest`.
- The layout is chosen with the normal Rails `layout`, not an Inertia option. `config.parent_controller` affects only shorthand `inertia` routes.
- In development the Vite plugin renders SSR; no Node server is needed. In production the SSR bundle is a separate Node process (Node 22 or newer). When it fails, the page falls back to client rendering and the error goes to `Rails.error` or `on_ssr_error`. `ssr_raise_on_error` is for tests. The default `ssr_timeout` is 10 seconds.
- Server-managed meta tags (`render inertia: …, meta: […]`) give correct tags without SSR. Use them, so tags survive an SSR failure.
- Only the `notice` and `alert` flash keys reach the client by default.
- A redirect from an Inertia request to a page that is not an Inertia page needs `inertia: { full_page: true }` or `inertia_location`. Use plain `<a>` for links to old pages.
- `xsrf_cookie_refresh: :lazy` stops the XSRF cookie being rewritten on every response.
- Prop helpers that fit this sprint: `defer` (previews), `optional` and partial reloads (filters, preview paging), `once` (vocabularies), `always`. `lazy` is deprecated.
- RSpec matchers: `render_component`, `have_props`, `have_exact_props`, `have_no_prop`, `have_flash`, `have_deferred_props`; helpers `inertia_reload_only` and `inertia_load_deferred_props`.
- Typelizer 0.14 writes types from Alba serializers and route helpers that return `{url, method}`. It watches files in development (`TYPELIZER=false` turns that off). It has no built-in drift check.
- The upstream React starter kit moved from `vite_rails` to `rails_vite` in 2026, and it uses Puma. Its Vite and SSR setup does not transfer; its Inertia conventions do.

### Prototype facts (`../qul-redesign/ds`)

- Dependencies to carry: react 19, the unified `radix-ui` package, `vaul`, `lucide-react`, `class-variance-authority`, `clsx`, `tailwind-merge`, `tw-animate-css`. No router, no command-palette library, no Vite.
- Tokens are CSS-first Tailwind 4 in `src/styles/qul.css`: oklch variables on `:root`, a `.dark` override block, a `@theme` mapping and `@custom-variant dark`. `ds-entry.css` and `build-ds.mjs` are for a design-tool bundle and are not ported.
- Fonts in `ds/fonts/`: Host Grotesk, Geist Mono and Noto Naskh Arabic (variable woff2), plus Digital Khatt and IndoPak Nastaleeq for Quran text samples.
- Components: 8 `ui` files and 10 `qul` modules, about 95 exports, typed props, no mock-data imports. Browser APIs appear only in effects or handlers, in `chrome.tsx` (key hint, hash writes, a global key listener), `nav.tsx` (hash listener, computed style), `theme.tsx` (class toggle, no persistence, no system preference), `github.tsx` (a fetch with a module-level cache) and `shards/` (WebGL with a webp fallback).
- Shortcuts to replace: the hash router and `window.location.hash` writes; query parsing from the hash; values parsed out of display strings (pages, lines, reciter); the in-memory theme; ⌘K that only focuses an input; the bundle tray and request dialog state.
- Only the mushaf-layout type page and a layouts-only detail page exist. The mock data has no types for files, relations or licences.
- The working tree has uncommitted edits to the apps, catalog and home pages and to `chrome.tsx` and `nav.tsx`. The working tree is the reviewed state.
- The repo's `brief.md` and research files name pages outside this sprint. The PRD decides scope.

### Catalog data facts (all countable on the public site or its public API)

Read `../qul-data/audit-2026-11-02.md` before writing a backfill. The points below are the ones that change design.

- There are 14 resource types and a few hundred published resources; translations, recitations and tafsirs are the large types, and four types hold one resource each.
- Slugs exist on a small minority of resources. One slug is an empty string. A slug must never be all digits, because `find_by_slug_or_id!` falls back to `find`.
- The resource id and the resource content id are independent id spaces. Old URLs use the resource id; `/api/v1` uses the content id. Two resources share one content row.
- Names repeat inside a type in about two dozen groups. Recitations differ by style and by surah or ayah form, which the content database holds; scripts differ by granularity; translations and tafsirs differ by language.
- Some approved recitation content rows have a blank name; the matching recitation row in the content database has the proper name.
- `cardinality_type` is set on every resource. `position` is unused. `short_summary` is almost empty. `info` holds editor HTML on a few dozen rows.
- Language is on the CMS row for translations, tafsirs, transliterations and surah info, with a few gaps that the content row fills. Language names are in the content database; many languages lack a native name and a few lack a direction.
- There are about two dozen distinct `file_type` strings, several of them variants of JSON and SQLite. Every file has exactly one blob, and every blob is a zip or bz2 archive with a byte size and a base64 MD5 checksum. `content_type` is unreliable. No uncompressed size exists.
- Version and export dates are meta keys on the content row (`exported-version` is a unix time and covers less than half of the resources). The fallback "updated" date is the newest blob date.
- The CMS row's `meta_data` is nearly empty. Font and script facts (`text-type`, `font`, `mushaf`, `font-face`, format keys, `preview-pattern`) are meta keys on the content row, some as free text.
- Related-resource links: a few dozen rows, all between scripts, fonts and layouts; one exact duplicate; one with a missing end. Half of the published layouts have no link.
- No field links a layout to its font. The link is implied by the mushaf's font name and by CSS class names. The glyph-per-page layouts (QPC V1, V2, V4 Tajweed) use one font file per page, with family names of the form `p{N}-v2`, from `quran_fonts/{v2,v1-optimized,v4-tajweed}/` on the CDN.
- Two code paths build font URLs and disagree on host and format priority (`ResourcePresenter#build_font_assets` and `shared/_resource_font_face.html.erb`). V4 Tajweed has no `font-face` key and one font's value has a typo.
- Layout facts (pages, lines, font) are in `quran.mushafs`, joined by resource content id. One content row maps to two mushafs, and the existing lookup has no order. Page words are in `mushaf_words`, ordered by line and position; that table has no index on mushaf and page. Special-line alignment is in the CMS database (`mushaf_line_alignments`); lines without a row are justified.
- Known layout data errors: one published layout's mushaf is disabled and has no word rows; one has more page rows than its page count; one has almost no bismillah alignment rows. Two mushafs are flagged default and neither has a published layout, so the data cannot say which layout to recommend.
- Other visible data errors: a few published resources have no files (two on purpose, as restricted); a few are published on content rows that are not approved.
- Tags: a few taggings point at resources that no longer exist; many tags are language names or repeat the type; several are spelling variants of each other.
- Licences: the table is empty. Three resources are marked restricted through the `copyright` meta key on the CMS row.
- Change logs exist for a few dozen resource contents.
- Eight types have no per-resource sample data for a preview: mutashabihat, similar-ayah, ayah-theme, ayah-topics, morphology, quran-metadata, font, and part of quran-script.
- `/api/v1` pieces that previews can call in process: chapter verses with words, translation and tafsir by range, and audio segments (keyed by recitation id). Its `per_page` handling is unreliable for small sizes. Two JavaScript callers on main point at endpoints that do not exist; do not copy them.
- Backfills must be idempotent and keyed on stable fields, because editors keep changing production while development runs on the snapshot.

---

## Gotchas & Patterns

_Append new entries at the END. Heading: `### <short topic> — <STORY_ID>`. Never edit or reorder existing entries._

### Pushing and PRs are allowed — ralph-init

The repo's Ralph constitution (`.agents/ralph/constitution.md`) now exists and replaces the interim protected-surface list above. Builders may push `qul-next` and sprint branches and open draft PRs. Never push or commit to `main`. Merging to `main`, the production database, and production config and credentials stay human-only. The "Never push, open a PR or run `gh` write commands" line in the planning notes above no longer applies.

### Planning facts re-checked at 3d805f64 — 001-01

Checked with `git diff 30bec50e 3d805f64` and against the snapshot.

- `config/routes.rb`: the old resource route table is unchanged (`/resources/:id` is the type page, `/resources/:type/:id` the detail page, the four-tab route, `/search` is Quran text search). New since planning: the proofreading routes were renamed and joined by contributor routes, so the helpers `translations_path`, `tafsirs_path`, `transliterations_path`, `topics_path`, `themes_path` (`/ayah_themes`), `arabic_roots_path` (`/roots`), `stems_path`, `lemmas_path`, `word_roots_path`, `similar_ayahs_path` and `word_texts_path` are taken. Name new catalog routes so they do not collide. The qiraat stack's proofreading-route edits no longer match main.
- `db/schema.rb`: version `2026_11_02_160000`, with seven new `draft_*` tables. The snapshot stops at `2026_10_23_140000`, so it lacks those seven migrations. Development raises `PendingMigrationError` on every page (`migration_error = :page_load`) unless the database has them; `bin/snapshot-clones` applies them to the clones without touching the snapshot or dumping the schema. Extensions are still only `plpgsql`.
- `bin/setup`: only a comment changed. It still runs `db:create:all` and `db:prepare`; never run it against the snapshot.
- SQLite exports: each export now drops and recreates its table inside the `.db` file instead of `CREATE TABLE IF NOT EXISTS`. No planning fact depended on this.

### Test-env and boot traps — 001-01

- `config/initializers/hosts.rb` adds hosts in every environment, so test is no longer allow-all: request specs need `host! 'localhost'` (`spec/clone_helper.rb` does it for `type: :request`).
- `require 'dotenv'` before Rails is loaded skips dotenv's railtie, so `.env` is not loaded in development either. Scripts that require it early call `Dotenv.load` themselves.
- Rails needs a JavaScript runtime (ExecJS) to boot, even for rake tasks.
- `escompress` shells out to `node_modules/esbuild` while rendering inline scripts; when esbuild cannot run (host `node_modules` inside a Linux container) it logs an error and the page still renders.
- `Gemfile.lock` lists no Linux platform. In a Linux container, install platform gems such as `tailwindcss-rails` there only; never add a platform to the lockfile (it would break parity with the qiraat stack).

### Yarn resolutions and new npm packages — 001-02

- The `resolutions` in `package.json` apply to every copy of a package, so new packages get the pinned major (Vite and Vitest run on picomatch 2, typescript-eslint on minimatch 3). Path-scoped resolutions (`**/vite/picomatch`) crash yarn 1.22 with "should have a resolved reference" when two of them name the same package. Check `yarn.lock` after `yarn add`, and test the new tool instead of assuming its declared range.
- Adding packages can move a shared dependency's hoisting (tslib moved under `@swc/helpers`). esbuild then writes a different path comment into `application.js`, so its checksum changes while the code does not. Compare old bundles by content without path comments, not by checksum.
- `eslint-plugin-ssr-friendly` 1.3 fails on ESLint 9 (`context.getScope is not a function`). SSR safety is checked by the `*.ssr.test.tsx` render tests instead.
