# Decision log

Decisions that are hard to reverse, newest sprint last. Each entry gives the decision, why it
was made and what it costs. Terms are in [`GLOSSARY.md`](GLOSSARY.md); how the code follows
them is in [`AGENTS.md`](AGENTS.md).

## Sprint 001: Inertia foundation and catalog

### New pages are Inertia inside this Rails app

- **Decision:** the new site is Inertia + React 19 + TypeScript + Vite inside this Rails app,
  beside the existing pages. There is no separate front-end app.
- **Why:** one deployable, one auth and session, and the old pages keep working unchanged.
- **Cost:** two front-end pipelines (Sprockets, esbuild and Tailwind 3 for the old pages; Vite
  and Tailwind 4 for the new ones) live in one repo until the old pages go.

### Work lands on `qul-next`, never on `main`

- **Decision:** sprint branches are cut from `qul-next`, which is cut from `main`. Nothing is
  committed on `main`, and merging to `main` stays with a human.
- **Why:** every push to `main` deploys.
- **Cost:** `qul-next` has to be kept merged with `main` while it lives.

### Plans live in this repo, sensitive context does not

- **Decision:** sprint files, the rule doc and the code live in this public repo. Connection
  details, data-safety background and anything from private tables stay in private notes
  outside it.
- **Why:** one repo and one loop, with the plan next to the code it describes.
- **Cost:** every committed plan, handoff and lesson is public, so it describes rules and
  behaviour, not data or weaknesses.

### Server-side rendering is on, with client rendering as the fallback

- **Decision:** new pages are rendered on the server (a spike proved it); when the SSR process
  fails or is slow, the page renders in the browser.
- **Why:** search engines and first paint get real HTML, and an SSR failure never takes a page
  down.
- **Cost:** a Node process beside Passenger in production, and every page must render without
  browser globals (SSR render tests guard it).

### Shapes are defined once in Alba serializers

- **Decision:** Alba serializers define the prop shapes; Typelizer generates the TypeScript types
  and route helpers, which are committed; `bin/rails typelizer:check` fails on stale output.
  Query objects and serializers know nothing about controllers or Inertia, so the public API
  can reuse them.
- **Why:** no hand-mirrored types between Ruby and TypeScript.
- **Cost:** generated files appear in diffs, and some serializers need the database to
  regenerate.

### Fewer, deeper stories

- **Decision:** the sprint is planned as fewer stories that each deliver a working slice.
- **Why:** less handoff overhead and fewer half-built surfaces.
- **Cost:** each story is larger to review.

### The page group setting is a deploy-time variable

- **Decision:** `QUL_PAGE_GROUPS` is an environment variable read by routing constraints, not a
  database flag or a per-user preview switch.
- **Why:** no new dependency, no request-time lookup, and switching back is a config change.
- **Cost:** a switch needs a restart, and there is no staff-only preview in production.

### Catalog search runs in Ruby over the loaded catalog

- **Decision:** catalog search is a query object that loads the published catalog once and
  normalizes, filters, counts facets and sorts in Ruby.
- **Why:** no Postgres extension is enabled, the searched text spans two databases, and facet
  counts become tallies.
- **Cost:** it loads every published resource per request, so it moves into SQL behind the same
  interface if the catalog grows into the thousands.

### `recommended` is a flag, not a status

- **Decision:** `recommended` is a boolean separate from the lifecycle status (stable, beta,
  legacy, superseded).
- **Why:** endorsement is not a lifecycle stage, and a status filter of stable must keep the
  recommended resources.
- **Cost:** one more computed field.

### The catalog fields are computed when read, not stored

- **Decision:** the display name, script family, rendering, lifecycle status and replacement, the
  recommended flag, the requires-link from a layout or glyph script to its font, and the summary
  of a resource without one are computed from the catalog on each request (`Catalog::Derived`,
  rules in `Catalog::Inference` and `Catalog::DisplayNames`). No column holds them, and the new
  pages add no column to `downloadable_resources` or `downloadable_related_resources`. The stored
  values are the slug, because a URL must not change, and an editor's `short_summary`, both in
  columns that already existed.
- **Why:** the values are copies of facts the data already has (content meta keys, the mushaf,
  the resource name). A stored copy needs a migration and a backfill at cutover, and it goes stale
  for every resource added later. Computed values need neither, and a new resource is right at
  once. This replaces the stored columns, the review column and the drafting backfills.
- **Cost:** every catalog request loads the whole catalog (a few hundred rows, a fixed number of
  queries). A display name can change when an editor adds a resource with the same name; slugs do
  not. There is no record of who checked a computed value.

### An editor corrects a catalog field with a meta data key

- **Decision:** a key in the resource's `meta_data` (the JSON editor of the CMS form) overrides
  the computed value: `display-name`, `script-family` (`madani`, `indopak`, `other`), `rendering`
  (`unicode_font`, `glyph_page`, `image`, `svg`), `status` (`stable`, `beta`, `legacy`,
  `superseded`), `superseded-by` (the slug or id of the replacement) and `recommended` (`true` or
  `false`). An invalid value is ignored and the computed value shows.
- **Why:** editors already edit `meta_data`, so corrections need no developer, no new column and
  no CMS form change.
- **Cost:** the keys are free text: a typing error is ignored without a message. The review
  report lists the keys.

### Anonymous downloads are a plain counter

- **Decision:** an anonymous download adds 1 to a separate counter column on the file with an
  atomic update. No cookie, no visitor id, and the request's address is never used.
- **Why:** nothing about a visitor is stored, there is no table to purge, and it matches
  signed-in counting, which is not deduplicated either. The column is separate so the
  signed-in recount cannot erase it.
- **Cost:** repeated requests and scripts count every time.

### The apps directory is a file in this repo

- **Decision:** the apps directory data is `config/apps.yml` with icons, behind a serializer;
  submissions come through a GitHub issue form.
- **Why:** a small, slow-changing list with a public review trail and no schema.
- **Cost:** featuring an app needs a commit and a deploy.
- **Superseded** by the Sprint 002 decision "The apps directory moves into the CMS database".

### The branch has its own database-free CI

- **Decision:** `.github/workflows/qul-next.yml` runs typecheck, lint, format, Vitest and both
  Vite builds on `qul-next`, `sprint/**` and `stack/**`. Request specs and browser tests stay
  local.
- **Why:** CI has no database and the specs need the snapshot clones.
- **Cost:** RSpec and Playwright depend on contributors running `bin/gate` and
  `yarn test:browser` before pushing.

## Sprint 002: Content pages and guided setup

### The apps directory moves into the CMS database

- **Decision:** apps are rows in the CMS database, submitted through a form on `/apps` by
  signed-in users and published by an editor. This replaces the sprint 001 decision "The apps
  directory is a file in this repo"; `config/apps.yml` becomes the one-time import source.
- **Why:** editors can approve, edit and feature apps without a commit and a deploy, and
  submitters do not need a GitHub account.
- **Cost:** a new table and CMS screen, an icon upload to storage, and no public review trail.

### Public writes need sign-in and have a daily limit counted in the database

- **Decision:** app submissions, requests and votes need a signed-in user. A user can send at
  most 5 requests and 3 app submissions a day, counted from the user's own rows. A vote is one
  row per user and request.
- **Why:** development and test use a cache that stores nothing, so a cache-based limit could
  not be proven locally; a row count is a model rule with request specs.
- **Cost:** no limit by address, and one count query per submission.

### Kits are a file in this repo, and the bundle lives in the browser

- **Decision:** kits are a curated file read through one class; the bundle is a list kept in
  the visitor's browser, and it downloads file by file through the existing download route. No
  zip is built.
- **Why:** kits are few and change with the catalog review, and a browser list needs no
  account, no table and no change to the download rules or counts.
- **Cost:** a kit change needs a commit and a deploy, a bundle does not follow the visitor to
  another device, and a bundle of many files is many downloads.

### Three more page groups

- **Decision:** `content` (docs, FAQ, credits, the tools overview, the changelog), `start` (the
  guided setup and kits) and `requests` join `home`, `catalog` and `apps`.
- **Why:** content pages can go live before the write paths are agreed.
- **Cost:** every group needs specs for both states, and links between groups must work with
  any combination.

## After sprint 002

### An app has a type, and store and source links

- **Decision:** an app is an App, Library, Tool or Data or API (`project_type`). Only an app has
  platforms (iOS, Android, Web, Desktop) and App Store and Google Play links; any type can have a
  source code link beside its main link. A submission asks for a short description. Library,
  tool and dataset are no longer platforms.
- **Why:** the directory serves people looking for an app and developers looking for code or
  data, and `platforms` mixed the two. Adapted from PR #1051, without its API, AI model and Other
  types (no app has them; Data or API covers the first two), its owner name and type (the store
  page or repo names the maker), its free-text resources field (`uses` is structured) and a
  website link separate from `url`.
- **Cost:** three more link columns and a type to keep right in the CMS; a new type needs a
  constant and its label.

## Storage

### Object storage stays on its current provider (2026-11-19)

- **Decision:** object storage stays on the current S3-compatible provider; a move to
  Cloudflare R2 was prepared and set aside. The storage code from #1072, #1073 and #1075 stays,
  because settings drive it and it works there unchanged: the three Active Storage services
  keep their names (`qul_exports`, `database_backups`, `amazon_s3`) and read the
  `QUL_STORAGE_*` settings, public links (`qul_exports`) start at `QUL_STORAGE_PUBLIC_HOST`
  (`R2Service`), private files get signed links that last a day, and
  `bin/rails storage:verify` and `bin/rails storage:fix_sizes` check and correct blob rows.
- **Why:** the team chose on 2026-11-19 not to move storage. The kept code reads its
  provider from settings, so it works on the current one as it is.
- **Cost:** `R2Service` and `service: R2` keep a name that no longer says where files are, and
  neither does `amazon_s3`, which points at the storage endpoint, not AWS.
