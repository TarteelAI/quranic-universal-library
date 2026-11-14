# QUL agent guide

General setup, build commands and file locations are in
[`.github/copilot-instructions.md`](.github/copilot-instructions.md). This file covers running
the app on a local copy of the production snapshot, the test harness, and the quality gate.
Terms (page group, download mode, drafted value, …) are defined in [`GLOSSARY.md`](GLOSSARY.md);
the decisions that are hard to reverse, with why and what they cost, are in
[`DECISIONS.md`](DECISIONS.md). Settings the app reads are listed in `.env.sample`.

This repo is public. Commits, sprint files, handoffs and lessons never hold production data,
anything from user, download, draft or admin tables, credentials or connection strings, and
describe the rules the code follows rather than weaknesses of the running site.

## Quality gate

```bash
bin/gate                 # standalone tests, RuboCop on changed files, generated-types drift check,
                         # tsc, ESLint + Prettier, RSpec and Vitest; needs fresh test clones and
                         # the development clones
```

In the Docker setup (`qul-dev`, below) `bin/gate` cannot run whole in one place: the container
has no yarn and an old Node, and the host may lack a Ruby in the Gemfile range. Run the Ruby
steps in `qul-dev` (the standalone tests with `RUBYOPT=-rbundler/setup`, `bin/rails
typelizer:check`, `bundle exec rubocop <files>`, `VITE_RUBY_AUTO_BUILD=false bundle exec
rspec`) and the yarn steps plus `node_modules/.bin/vite build --ssr` on the host, the SSR build
before RSpec.

Narrow checks while working:

```bash
ruby -Itest test/path/to/file_test.rb        # standalone tests: no bundler, no database
bundle exec rspec spec/path/to/file_spec.rb  # specs: Rails on the test clones
bundle exec rubocop path/to/file.rb          # RuboCop (.rubocop.yml); bin/gate runs it on changed files
bin/rails typelizer:check                    # generated TypeScript is current (development env)
yarn typecheck                               # tsc on app/frontend
yarn lint:frontend && yarn format:frontend   # ESLint and Prettier on app/frontend
yarn test:frontend                           # Vitest (component and SSR render tests)
bin/vite build --ssr                         # SSR bundle that request specs using SsrServer need
yarn test:browser                            # Playwright against real Rails (see Browser tests)
```

What CI runs and what stays local:

- `.github/workflows/qul-next.yml` runs on pushes to, and pull requests based on, `qul-next`,
  `sprint/**` and `stack/**` (never `main`). It needs no database, `.env` or secret: install
  (`--frozen-lockfile --ignore-scripts`), `yarn typecheck` (which also compiles the committed
  generated types and routes), `yarn lint:frontend`, `yarn format:frontend`,
  `yarn test:frontend`, `vite build` and `vite build --ssr`.
- `.github/workflows/tests.yml` runs the standalone `test/` suite on every pull request.
- Local only, because they need the snapshot: `bin/rails typelizer:check` (some serializers
  read column types from the database), RSpec and `yarn test:browser`. Run `bin/gate` before
  pushing.

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

### Page groups

New pages take over existing URLs one page group at a time. `QUL_PAGE_GROUPS` is a deploy-time,
comma-separated list of the groups the new pages serve: `home`, `catalog` (`/resources` and
below), `apps`, `content`, `start` and `requests` (`PageGroups` in `app/services/page_groups.rb`). Unset means every
URL is served by the old ERB views. A group takes over only the URLs that have a new page so far (for
`catalog`: `/resources`, `/resources/:type` and the detail page `/resources/:type/:slug`); the
rest of the group stays on the old views. `home` serves `/` (`Site::HomeController`; off, the old
landing page). `apps` serves the apps directory `/apps` (`Site::AppsController`), which has no old
page: off, it is a 404 and no new page links to it. Its entries are the published `App` rows of the
CMS database (`AppDirectory`, featured first; the home page's apps band shows the first eight),
which editors publish, edit, feature and remove in the CMS (`/cms/apps`, admins only). `bin/rails
apps:import` makes the entries of `config/apps.yml` (icons in `public/app-icons`) published rows
once, keyed on the entry id (`import_key`): an entry that has a row is skipped. Its "Submit your
app" form (`?submit=1` opens it; the home page's button links there) posts to `POST /apps`
(`Site::AppSubmissionsController`), which needs a signed-in user, takes at most
`App::DAILY_LIMIT` submissions per user and day, and stores an unpublished `App` row.
`content` serves the docs index `/docs` and `/docs/:key` (`Content::DocsController`, body from
`Content::DocPage`, side navigation from `Content::DocsNavigation`, both read from
`config/docs.yml`) for page loads and Inertia visits only (`Content::DocsRequest`): the old pages'
help dialogs fetch `/docs/:key` with `fetch` (Accept `*/*`) or as XHR and keep the old answer, and
so do the keys only an ERB partial under `app/views/docs` serves. The docs search index
`/docs/search-index` (`Content::DocsSearchIndex`, JSON) belongs to the group too: the docs layout's
search field and the spotlight's Docs group fetch it once per page load, on first use, and match in
the browser (`lib/docs-search.ts`); the shared `nav.docsSearch` says whether it exists.
`content` also serves `/faq`, `/credits` and the tools overview `/tools` (`Content::PagesController`).
They read what the old pages read; FAQ answers and credits descriptions are editor HTML reduced to
prose on the server (`Content::Prose`). The tools overview groups `ToolsHelper#developer_tools` as
the Contribute menu does (`SiteNav::ContributeTools.overview`) and links to the old tool pages.
`content` also serves the changelog `/changelog` and `/changelog/:id` (`Content::ChangelogController`,
entries from `Content::Changelog`, 20 per page, an out-of-range `?page=` is a 404). The old
`/change_logs` URLs answer 301 there (an old page of 10 goes to the new page holding its entries),
and the detail page's Changelog tab links to the new entries.
`start` serves the guided setup `/start` (`Start::SetupController`), which has no old page: off,
it is a 404 and no new page links to it. Its answers are in the query string (`goal`, `platform`,
`feature`, `script`, `lang`, comma lists; `GuidedSetup::Answers`), and it opens at the first
unanswered step. It ends on `/resources?goal=…`, which the routes send to the setup's results
while `start` and `catalog` are both on: a section per need (`GuidedSetup.result`, which maps the
answers to checklist items, each with the catalog filters that list it) with its first cards and a
link to that catalog search. With `catalog` off the setup ends on a plain link to `/resources`.
`start` also serves the starter kits `/kits` and `/kits/:key` (`Start::KitsController`): curated
sets of resources in `config/kits.yml`, read through `Kits`, which name each resource by slug
(`spec/services/kits_spec.rb` fails when one is not published; an item unpublished later drops out
of its kit). With `start` on, the home page shows the goal cards (each opens `/start?goal=…`) and the
first three kits, its hero and closing buttons open `/start`, and the header has the Start building
menu; with it off, none of them appear.
`requests` serves resource requests, which have no old page (off, they are 404s and the request links
of the new pages open the GitHub issue form). The public list `/requests` (`Requests::RequestsController#index`)
sorts by votes or, with `?sort=date`, newest first, 20 to a page (an out-of-range `?page=` is a 404).
With the group on, `nav.request` is `/requests?request=new`: `?request=new` opens the request dialog
(`components/qul/request-dialog.tsx`, in `SiteShell`) on any new page, which is where sign-in returns,
and the request cards open it in place. `POST /requests` creates one, `POST /requests/:id/vote`
votes and `DELETE /requests/:id/vote` takes the vote back (`Requests::RequestsController`). Each needs a signed-in user, goes back to the page it came
from and enqueues nothing; a user sends at most `ResourceRequest::DAILY_LIMIT` requests a day. A vote
is one row per user and request (unique index `index_resource_request_votes_unique`, inserted with
ON CONFLICT DO NOTHING). The public list is `Requests::ListQuery`: visible requests with vote counts
and whether the current user voted, by votes or by date, one query a page, and no author or voter.
Editors set the status and hide requests in the CMS (`/cms/resource_requests`, admins only).
The spotlight's JSON endpoint (`/spotlight?q=…`, `Catalog::SpotlightController`) is outside the
groups, for every new page: the header's search button and ⌘K / Ctrl K open the spotlight.

- The catalog page (`/resources`) keeps every filter, the query, the sort, the page and the view
  (`view=list`; grid is the default) in the query string. A filter change is a partial reload
  (`only` the search props, `preserveState`) that adds a history entry; typing searches after a
  pause and replaces the entry. Back restores the page from history and remounts it, so local
  state starts again from the props. With no sort and no query the results are ordered by
  category (taxonomy order, most downloaded first in each) and `groups` names the category runs
  on the page; with either, they are one list. A type page with more than
  `Catalog::TypesController::SEARCH_ABOVE` resources is searched the same way (`q`, `language`,
  `page` in the query string, through `Catalog::SearchQuery`), 24 cards to a page.
  `category=<key>` filters the catalog to one category (the home page's category rows link
  there). The home page's data showcase loads each tab's preview as an optional prop
  (`recitationPreview`, …) once the open tab nears the screen (`WhenVisible`).

- New routes go in the one block in `config/routes.rb` that wraps them in
  `constraints(PageGroups.constraint(:catalog))`. The block sits above the old routes for the same
  paths: when the group is off the constraint fails and the old route answers, so turning a group
  off restores the old page with no code change. The setting is read per request.
- Request specs set the groups per example group: `page_groups: %w[catalog]` or
  `page_groups: []` (`spec/clone_helper.rb`). Write a spec for both states.

### Card previews (sprint 002, story 002-03)

A resource card on the catalog and type pages shows a preview fitted to its type. The page props
carry only each card's `previewKind` (`Previews::Card.kind`); the card fetches the preview as JSON
from `/resources/:type/:slug/preview` (`Catalog::PreviewsController`, catalog group) once it comes
within 200 px of the viewport (`components/previews/card-preview.tsx`), so its fonts are declared
and downloaded only then. The JSON is the detail page's provider (`Previews.for`) asked for the
start of the Quran and cut by a card serializer (`Previews::Card*Resource`): a layout's page 1,
a recitation's Al-Fatihah, ayah 1:2 of a script, translation, transliteration or tafsir (text cut
to `Previews::Card::TEXT_LIMIT`), and a line in a font. A 404 or an unexpected kind removes the
preview well and the card shows without it. The record types have no entry in
`Previews::Card::KINDS`: their cards show the type icon beside the title instead. Each card
names its own V4 colour palette (`paletteName` of `FontFaces`), so the cards of one page do not
replace each other's palette rule.

### Downloads

Files download from `/resources/:type/:slug/download/:file_id` and from the old token URL
`/resources/:type/:token/download`, which the routes send to the same controller
(`Catalog::DownloadsController`) whatever the page groups. Both end in a redirect to the file's
storage URL, so a download link is a plain `<a>`, never an Inertia visit.

- The bundle tray (header, `components/qul/bundle.tsx`) lists these same links, so it changes no
  download rule or count. The bundle is a list of resource ids in `localStorage` (`qul-bundle`,
  `lib/bundle.ts`); the server never stores it, and the server render and hydration see it empty.
  The tray asks `/bundle?ids=…` (`Catalog::BundlesController`, catalog group) what the ids are
  now: an id that is no longer a published resource, and a restricted resource, come back
  without files and show as unavailable. With `catalog` off there is no tray (`nav.bundle`).
- `QUL_DOWNLOAD_MODE` (`DownloadMode`): `sign_in` (the default) sends an anonymous visitor to
  sign-in, which returns to `/resources/:type/:slug?download=<file id>` (with the `catalog` group
  off, to the download URL itself, because the old page ignores the parameter). The detail page
  starts that download in a hidden frame and takes the parameter out of the URL; `public` sends
  the file without an account. An unknown value stops the boot. Request specs set it with
  `download_mode: 'public'`.
- In both modes an unpublished file or resource is a 404, and a restricted resource is blocked
  for everyone but admins.
- Counting: a signed-in download increments the user's row (`user_downloads`) and
  `download_count`; an anonymous one adds 1 to `anonymous_download_count`. Nothing about an
  anonymous visitor is read or stored, and its response sets no cookie, so the counts are counts
  of requests: a repeated request or a script counts every time. HEAD requests count nothing, and
  `robots.txt` and `X-Robots-Tag: noindex` keep well-behaved crawlers out.
  `DownloadableFile#total_download_count` is the combined total popular sorting reads.

### Conventions for a new page (example: `/resources/:type`)

- Controller: inherit `InertiaController`, in its own namespace (`Catalog::TypesController`).
  Old controllers, presenters and views stay untouched.
- Page props: an Alba serializer named after the action (`Catalog::TypesShowResource` for
  `Catalog::TypesController#show`), built by `render_inertia` from the action's instance
  variables. Data comes from query objects and serializers that do not know about controllers,
  Inertia or the session (`Catalog::ResourcesQuery`, `Catalog::ResourceCardResource`), so the
  public API can reuse them. CMS and content rows are preloaded in separate queries (`preload`),
  never joined.
- Copy that is shared by several pages lives in one server-side file and goes to the page as
  props: the catalog taxonomy (type labels, descriptions, categories) is `Catalog::Taxonomy`.
- Head: `render_inertia '<page>', meta: page_meta(title:, description:, json_ld:)`. `PageMeta`
  writes the title, description, robots, Open Graph, Twitter, the canonical link on the
  production host (`SeoHelper::HOST`) and the JSON-LD script.
- Errors: `ActiveRecord::RecordNotFound` in an Inertia controller renders `errors/ErrorPage` with
  status 404 in the new layout (in development too).
- Layout (`inertia.html.erb`): the theme script, the Sentry loader (not in development) and GA4
  with `send_page_view: false`. `app/frontend/lib/analytics.ts` sends one page view on the first load
  and one after every Inertia visit. The GA4 tag also forwards each event to a second
  measurement id, so each page view leaves the browser twice.
- The detail page (`Catalog::ResourcesController#show`, props from `Catalog::ResourcePage`) is the
  only URL of a resource: an id URL, a wrong type and the old `/:tab` and `/copyright` URLs
  redirect to it with a 301. Its open tab is `?tab=` (a client-side `router.push`). The Data and
  Docs tabs come from the old format-doc partial of the resource (`app/views/resources/docs`),
  rendered with the old presenter and parsed by `Catalog::FormatDoc`: the whole doc as docs
  segments for Docs, its column tables and lists and its first code block for Data. The partials
  stay the only copy; a resource whose partial is missing has no Docs tab.
- Links to old pages (contributor tools, sign-in, a page whose group is off) are plain `<a>` with
  the typed route helpers; links between new pages are Inertia `<Link>`.
- Shell: every page renders inside `SiteShell` (`components/layout.tsx`): the v7 header, the
  flash messages (`notice` and `alert`), the page and the footer. The header and footer links
  come from the server (`SiteNav`, shared prop `nav`, a once prop), and each link says whether a
  new page serves it (`inertia`), which depends on the page groups; `NavAnchor` renders an
  Inertia `<Link>` or a plain `<a>` from that. The Inertia version names the page groups
  (`config/initializers/inertia_rails.rb`), so a tab loaded under another setting reloads in full
  on its next visit and gets the current navigation. With `content` on, the only old pages the
  header, menus and footer link are the contributor tools and sign-in. The contributor tools in
  the Contribute menu are `ToolsHelper#developer_tools`. The shared prop `auth` holds only `{ user: { initials, name } }`
  or `{ user: null }`; sign-in links pass the current path as `user_return_to`.
- Theme: light and dark tokens in `app/frontend/styles/inertia.css`, switched by the `dark`
  class on `<html>`. An inline script in the layout sets it before the first paint from the
  stored choice (`localStorage` key `qul-theme`) or the system setting; `lib/theme.ts` keeps it
  in step after that. Components read the theme with `useTheme`, which is null on the server.
- Interface fonts are the `@fontsource-variable` packages, bundled by Vite and served by this app.
  The new layout loads no font or icon CSS from another host.
- The UI kit is `app/frontend/components/ui` (generic primitives on Radix, vaul and
  class-variance-authority) and `components/qul` (QUL pieces). More v7 components are ported
  when a page needs them. Each exported component needs an entry in `app/frontend/test/kit.tsx`:
  `components/kit.ssr.test.tsx` renders it on the server and `components/kit.test.tsx` hydrates
  that HTML and fails on a hydration mismatch.
- Tests per page: a request spec (props, both page group states, head), a Vitest component test
  and an SSR render test, and a Playwright spec for behaviour across pages. A request spec that
  must see server-rendered HTML wraps the request in `SsrServer.with_ssr { … }`
  (`spec/support/ssr_server.rb`), which starts `public/vite-ssr/ssr.mjs` with Node and fails when
  the bundle is missing or older than `app/frontend`.

### Integration answers (sprint 001, story 001-02)

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
- JSON requests that are not page visits: `useHttp` from `@inertiajs/react` sends the XSRF
  header and does not change the URL. The spotlight's GET needs no token and uses `fetch` with an
  `AbortController`, so each new query aborts the one before it (`components/qul/spotlight.tsx`).
- `yarn.lock` resolutions in `package.json` pin all copies of `picomatch` (2.x), `minimatch`
  (3.x) and `postcss`, including the copies Vite, Vitest and typescript-eslint ask for.
  Path-scoped resolutions crash yarn 1.22, so they are not used. The new tools work with those
  versions; typed linting with `allowDefaultProject` would not (it needs minimatch 10).

### Forms that write (sprint 002, story 002-02)

- A form only a signed-in user can send is a `GatedForm` (`components/qul/gated-form.tsx`): from
  the `auth` shared prop it disables every field (a `<fieldset disabled>`) and shows a sign-in
  link whose `user_return_to` is a URL that shows the form open. The server checks sign-in
  itself; an anonymous Inertia submit gets `inertia_location` to sign-in (a full visit, since
  sign-in is an old page).
- Submit with `useForm(...).post` (the XSRF header as above). With a `File` in the data Inertia
  sends multipart, otherwise JSON; `createInertiaApp` turns off `forceIndicesArrayFormatInFormData`
  so arrays arrive as `field[]`, which Rails reads as arrays.
- Validation errors: `redirect_back_or_to <path>, inertia: { errors: record.errors.to_hash(true) }`.
  They reach the next page as the `errors` prop, arrays of full messages (`errorValueType`), and
  `useForm` keeps the typed values because a post preserves state.
- Attachments: build the blob with `metadata: { analyzed: true }` (see `App#icon_upload=`), or
  attaching enqueues `ActiveStorage::AnalyzeJob`, and ActiveJob is Sidekiq outside test.

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

## Browser tests

Playwright (`playwright.config.ts`, specs in `spec/browser`) runs against real Rails in
development on the development clones, with Vite and SSR, at desktop (1280 px) and phone
(Pixel 7) width:

```bash
yarn playwright install chromium            # once
yarn test:browser                           # every spec, both widths
yarn test:browser catalog.spec.ts           # one file
LOOK_PATH=/resources/font yarn test:browser look.spec.ts   # screenshots of one path, both widths
```

- The command starts Vite (`localhost:3036`) and `bin/rails server -p 3000` with
  `QUL_PAGE_GROUPS=home,catalog,apps,content,start,requests`, or reuses servers already on those ports. When Rails runs
  in Docker, start it there first with the page groups set, plus the `socat` forward (below):
  `docker exec -d -e QUL_PAGE_GROUPS=home,catalog,apps,content,start,requests qul-dev bin/rails server -b 0.0.0.0 -p 3000`.
  The global setup stops the run when the reused server does not serve the catalog group.
- Each test prints a provenance line: `real backend`, or `mixed` with the routes it stubbed
  (stub through the `stubs.route` fixture in `spec/browser/support/test.ts`, never `page.route`).
  Every test answers GA4's collect requests itself, so no browser test sends page views to Google;
  the `analytics` fixture lists the page views a test sent. The real gtag.js still loads, so the
  GA4 spec needs network access.
- Output (traces, screenshots, the HTML report) goes to `tmp/playwright/`.
- `QUL_BROWSER_BASE_URL` points the run at another server.
- A second Rails server inside `qul-dev` (for example on 3001) is not on the host's `localhost`:
  the container publishes only 3000. Forward a host port to the container's IP
  (`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' qul-dev`) with a
  few lines of Node (`net.createServer`), since the app answers only a `localhost` Host.
- A run that migrates, imports or writes uses fresh clones under other names, so the
  development clones stay as they are: `QUL_CMS_CONTENT_DB_NAME=<x> QUL_QURAN_CONTENT_DB_NAME=<y>
  bin/snapshot-clones development`, with the same two variables on the server, the image and
  `QUL_BROWSER_RAILS_RUNNER`. App icons are stored on `qul_exports` in production, so the icon
  tests need development Rails (local disk); the whole suite runs there, and the new-page specs
  also run against the production image.

## Production image

`docker/README.md` has the recipe for building the production image and running it locally on
the development clones, with Sidekiq disabled and no SMTP variables, and how the Inertia SSR
service is run, logged and restarted. The image boots without the master key
(`SECRET_KEY_BASE` is enough). `.dockerignore` keeps `.env` files, `sprints/`, `.agents/`,
this file and local Vite builds out of the image.

## Code and build rules

- **Two databases.** The CMS database (`ApplicationRecord`) and the Quran content database
  (`QulQuranRecord`) are separate Postgres databases: SQL cannot join across them, so preload in
  two steps. New migrations use the CMS connection only; the content database is never changed.
- **Slugs** are never all digits: `find_by_slug_or_id!` falls back to `find`.
- **Backfills** are idempotent and keyed on stable fields, because editors keep changing
  production while development runs on the snapshot.
- **Cache.** Test and development use `null_store`; build nothing that needs the cache to be
  correct.
- **File URLs.** Without the storage variables a blob URL points at a placeholder host locally.
  Specs assert the redirect, never fetch the file.
- **`Word` order.** `Word` has a default scope ordered by `position`, so `order(...)` still sorts
  by position first. Use `reorder` whenever the order matters.
- **Font palettes.** `@font-palette-values` rules with the same name do not merge per family: the
  last one wins. When several V4 Tajweed page fonts share a screen, emit one rule whose
  `font-family` lists all of them, or give each preview's rule its own name (the resource cards).
- **Dependencies.** The Dockerfile installs no devDependencies (`NODE_ENV=production`): build
  tools are regular dependencies, test and lint tools are devDependencies. The `resolutions` in
  `package.json` apply to every copy of a package, so check `yarn.lock` after `yarn add` and run
  the new tool rather than trusting its declared range. `eslint-plugin-ssr-friendly` does not
  work on ESLint 9; the SSR render tests cover SSR safety.
- **Vite.** The entrypoint globs `../pages/**/*.tsx` minus `*.test.tsx`; a test file inside the
  glob pulls test libraries into the client bundle, which the image cannot resolve. vite_ruby
  checks `bun.lock` before `yarn.lock`, so `config/vite.json` pins `"packageManager": "yarn"`;
  leave the stray `bun.lock` alone.
- **Old pipeline.** The `build` script in `package.json` belongs to esbuild and jsbundling; do not
  change it for Vite. Do not run the Inertia or `vite install` generators: they inject tags into
  `application.html.erb` (which every old page uses) and may overwrite `bin/dev`.
- **Early `require 'dotenv'`** (before Rails loads) skips dotenv's railtie, so a script that
  does it calls `Dotenv.load` itself.
- **Comparing with `main`:** local `main` can be behind; compare with `origin/main` or
  `git merge-base origin/main HEAD`.

## Data safety

- Never run `db:test:prepare`, `db:schema:load`, `db:reset`, `db:drop`, `db:prepare`,
  `bin/setup` or anything that calls `maintain_test_schema!` against the snapshot.
- The snapshot's `ar_internal_metadata.environment` is `production`; leave it so.
- After `db:migrate`, commit only your own lines of `db/schema.rb`.
- Never start Sidekiq and never set SMTP variables locally.
