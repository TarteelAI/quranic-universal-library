# New site pages on Inertia: catalog, resource pages, home and apps

This merges `qul-next` into `main`. It adds new pages built with Inertia, React 19 and
TypeScript. They are served by this Rails app and rendered on the server. The old ERB pages are
not changed. Each group of new pages is switched on with a deploy setting. With the setting
unset, every URL serves the old page, as before.

The same commits are split into six smaller draft PRs for review: #1025, #1026, #1027, #1030,
#1031 and #1032 (each is based on the one before it). `sprints/001-inertia-foundation-and-catalog/STACK.md`
lists what each one holds.

## What changed

- **Foundation.** Vite (`vite_rails`) beside the old asset pipeline, Inertia pages in
  `app/frontend`, props from Alba serializers, generated prop types and route helpers
  (`typelizer`), server-side rendering with client rendering as the fallback.
- **Site shell.** The v7 header and footer, light and dark themes, sign-in state, flash
  messages, and a ⌘K / Ctrl K spotlight that searches resources from every new page.
- **Catalog** (`/resources`, `/resources/:type`). Search (Arabic too), filters with counts for
  type, language, script family, format, granularity and status, three sorts, a shareable URL
  for every view, and a filter drawer on phones.
- **Resource pages** (`/resources/:type/:slug`). A preview for each resource type, the files
  panel, the licence, related resources, and a "no preview" state where there is none. The old
  detail URLs redirect to the new ones.
- **Downloads.** `/resources/:type/:slug/download/:file_id` and the old token URL go to one
  controller. Sign-in is required by default; a setting makes downloads public. Anonymous
  downloads add to a plain counter. Nothing about the visitor is stored.
- **Home** (`/`) and **apps directory** (`/apps`), with a GitHub issue form to submit an app.
- **Catalog data.** New fields on resources (display name, slug, status, script family,
  recommended and others), filled by backfills. Each filled value is marked as drafted until a
  person reviews it.
- **Tests and CI.** RSpec request specs on clones of a production snapshot, Vitest component
  and SSR tests, Playwright browser tests, and `.github/workflows/qul-next.yml` (typecheck,
  lint, format, Vitest and both Vite builds, no database).

## How to run it

`AGENTS.md` has the full steps (local run, Docker, tests). In short:

```bash
bundle install && yarn install && yarn build && yarn build:css
bin/snapshot-clones development
QUL_PAGE_GROUPS=home,catalog,apps bin/dev     # http://localhost:3000
bin/gate                                      # the full local quality gate
```

`docker/README.md` covers the production image and its SSR service.

## Settings

| Variable | Values | Default | Effect |
| --- | --- | --- | --- |
| `QUL_PAGE_GROUPS` | comma-separated `home`, `catalog`, `apps` | unset (old pages everywhere) | Which URL groups the new pages serve. Read per request; removing a group brings its old pages back. |
| `QUL_DOWNLOAD_MODE` | `sign_in`, `public` | `sign_in` | Whether a download needs an account. An unknown value stops the boot. |
| `CDN_HOST` | e.g. `https://static-cdn.tarteel.ai` | unset | Base of font URLs in previews. |
| SSR service | `inertia-ssr` runit service in the image | on | Node on `127.0.0.1:13714`. If it is down or takes more than 2 s, the page renders in the browser. |

The featured apps in `config/apps.yml` are placeholders until the list is supplied.

## Migrations and backfill order

1. `bin/rails db:migrate` runs three CMS migrations:
   - `20261110100000_add_catalog_fields_to_downloadable_resources`
   - `20261110100100_add_relation_type_to_downloadable_related_resources`
   - `20261110120000_add_anonymous_download_count_to_downloadable_files`
2. `bin/rails catalog:backfill` runs every backfill in one transaction, in this order:
   blank slugs, display names, slugs, related links, taggings, script families, renderings,
   statuses, requires links, recommended, summaries. It prints the rows each step changed. A
   second run changes nothing, and values a person has edited are kept.
3. `bin/rails catalog:review_report` writes the drafted values and known data errors to
   `tmp/catalog-review-report.md` for the data team. The file is not committed.
4. `bin/rails "catalog:mark_reviewed[<slug>,<field>]"` marks a drafted value reviewed.

Both were replayed on a fresh restore of the production backups
(`sprints/001-inertia-foundation-and-catalog/VALIDATION.md`).

## Files shared with the qiraat stack

`origin/qiraat/p7-5-drop-legacy` (the top of the qiraat stack) also changes eight files this
PR changes. A trial merge of that branch into this one gives these results:

| File | Result | How to resolve |
| --- | --- | --- |
| `.gitignore` | Conflict: both add lines at the end | Keep both blocks (the Vite build folders and `!/db/quran_structure.sql`). |
| `config/routes.rb` | Merges cleanly where this PR adds routes. The qiraat branch already conflicts with `main` in the same file (proofreading routes) | Resolve the `main` conflict as the qiraat stack would. Keep the page-group block above the old routes. |
| `db/schema.rb` | Conflict on the schema version line only | Keep the later version (`2026_11_10_120000`). Both sides' tables and columns merge. |
| `app/models/downloadable_resource.rb` | Merges cleanly | This PR adds `include CatalogFields`; qiraat adds two resource types. Add catalog taxonomy entries (`Catalog::Taxonomy`) for `riwayah-text` and `ayah-numbering` when they land. |
| `Gemfile`, `Gemfile.lock` | Merge cleanly | Both add `rspec-rails ~> 7.1` in the test group; keep one. Run `bundle install` and commit the lock. |
| `.rspec` | Merges cleanly (same line) | None. |
| `spec/spec_helper.rb` | Merges cleanly (same generated file) | Specs here use `spec/clone_helper.rb` and never maintain the schema. The qiraat `spec/rails_helper.rb` calls `maintain_test_schema!`; it must not run against the snapshot clones. Agree on one helper before both suites run together. |

The other conflicts in a trial merge (29 files in all) are between the qiraat stack and the
current `main`, not this PR.

## Data-model decisions that need the maintainers' agreement

The full list, with reasons and costs, is in `DECISIONS.md` (Sprint 001). These change the
database or the data:

- New columns on `downloadable_resources` (display name, status, script family, recommended,
  a `review` record of drafted and reviewed values, and others), on
  `downloadable_related_resources` (`relation_type`) and on `downloadable_files`
  (`anonymous_download_count`).
- `script_family` (`madani`, `indopak`, `other`) is a separate word from qiraat's `scripts`
  table, which means one riwayah in one encoding.
- `recommended` is a flag, not a status.
- No CMS form changes: corrections and review marks go through rake tasks for now.
- Anonymous downloads are a plain counter with no visitor data.
- The apps directory is `config/apps.yml`, with submissions through a GitHub issue form.

https://claude.ai/code/session_015PLFa6ZMJdJCfHa56HCnfP
