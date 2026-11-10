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
- **Cost:** one more column and one more drafted field.

### No CMS form changes for the new catalog fields

- **Decision:** corrections and review marks go through a task; changing a drafted field outside
  a backfill counts as reviewing it.
- **Why:** keeps the CMS untouched for now.
- **Cost:** only a developer can apply corrections.

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

### The branch has its own database-free CI

- **Decision:** `.github/workflows/qul-next.yml` runs typecheck, lint, format, Vitest and both
  Vite builds on `qul-next`, `sprint/**` and `stack/**`. Request specs and browser tests stay
  local.
- **Why:** CI has no database and the specs need the snapshot clones.
- **Cost:** RSpec and Playwright depend on contributors running `bin/gate` and
  `yarn test:browser` before pushing.
