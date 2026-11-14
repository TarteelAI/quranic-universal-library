# Sprint 002 validation

Story 002-20, run on 2026-11-13 from `sprint/002-content-pages-and-guided-setup` at `cf08ffbd`
(002-19 and the layer 4 gate fix), plus the two fixes this story made (see
[Defects found](#defects-found-and-fixed)). Everything ran on one development machine: the
production image in Docker (`linux/amd64`, as production builds), Rails for specs, runner scripts
and the development server in the `ruby:3.3.10` container, Playwright and Vite on the host. The
machine's load average was 200 to 250 throughout, so the times below are upper bounds.

Every database was a clone of the 2026-11-02 snapshot: the test clones for RSpec, and two fresh
scratch clones made for this run (`bin/snapshot-clones development` with other database names),
used by the image, the development server and the runner scripts, and dropped afterwards. No
production credential, master key, SMTP setting or Sidekiq process was used.

This file is public. It holds counts and statuses only: nothing from user, download, draft or
admin tables, and no connection details.

## Exit criteria

| Criterion (story 002-20) | Result | Evidence |
| --- | --- | --- |
| The image builds for `linux/amd64` and, on clones, returns server-rendered HTML for a docs page, the guided setup and the requests page | pass | [Production image](#production-image-and-ssr) |
| The full Playwright suite passes at both widths with every group on | pass | [Full browser suite](#full-browser-suite) |
| The link sweep's old pages are only contributor tools, sign-in and the CMS | pass | [Link sweep](#link-sweep) |
| With each of `content`, `start` and `requests` off, the old page or the 404 answers at each URL, including the layout-free docs request | pass | [Switch back](#switch-back) |
| Fresh clones: migrate, import apps, import again changes 0 rows, an edited app is kept | pass | [Data replay](#data-replay-on-fresh-clones) |
| Write rules for app submissions, requests and votes on the running image | pass | [Write paths](#write-paths-on-the-running-image) |
| Icon upload proven with the local disk service; production storage is a human step | pass | [Icon upload](#icon-upload) |
| `bin/gate` passes, including Ruby linting | pass | [Gate](#gate) |

The PRD's exit criteria this file is the evidence for: the link sweep, docs parity
([Docs parity](#docs-parity)), the switch-back, the apps import replay and the production image
with SSR.

## Production image and SSR

`docker build --platform linux/amd64 --progress=plain -t qul-sprint002:validation .` exited 0
(3 min 12 s; the gem and package layers came from the cache, everything from `ADD . /home/app/qul/`
on was built fresh, including both `assets:precompile` runs). The image is `linux/amd64`. Log
tail:

```
#43 [39/44] RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
#43 47.76 public/vite-ssr/ssr.mjs                                   4.31 kB │ gzip:  1.53 kB │ map:   6.97 kB
#43 47.86 Build with Vite complete: /home/app/qul/public/vite
#43 DONE 48.0s
#44 [40/44] RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
#44 DONE 32.7s
...
#49 writing image sha256:ff75a57a0ab9c157769c73d1b82715a6928c8dbfde8297c0d7d470a4fc9c7739 0.0s done
#49 naming to docker.io/library/qul-sprint002:validation 0.0s done
build exit 0
```

The SSR build wrote one chunk per page, including this sprint's (`DocsPage`, `SetupPage`,
`RequestsPage`, `KitsPage`, `ChangelogPage`, …).

The container ran on the scratch clones with `SECRET_KEY_BASE` only (no master key), the Sidekiq
service disabled by a mounted `down` file, and
`QUL_PAGE_GROUPS=home,catalog,apps,content,start,requests`. The image declares four SMTP
variables from build arguments; all four were empty. `sv status`: `down: sidekiq`,
`run: inertia-ssr`, `run: nginx`. The process list had Passenger, `node … public/vite-ssr/ssr.mjs`,
redis and memcached, and only the `runsv sidekiq` supervisor (no Sidekiq process).

`curl` with an HTML `Accept` header (with `*/*` the docs URLs keep the old answer for the old
help dialogs, see [Switch back](#switch-back)). SSR: `data-server-rendered="true"` on `#app`.
Inertia: the `data-page="app"` script.

| URL | Status | Time | SSR | Inertia | `<title>` |
| --- | --- | --- | --- | --- | --- |
| `/docs/getting-started` | 200 | 0.12 s | yes | yes | Getting Started — Download Resources — QUL Documentation |
| `/docs/tutorial-recitation-end-to-end` | 200 | 0.08 s | yes | yes | Tutorial 1: Recitation End-to-End — Download Resources — QUL Documentation |
| `/docs/murattal` | 200 | 0.20 s | yes | yes | Murattal — QUL Documentation |
| `/start` | 200 | 0.88 s | yes | yes | Start building - QUL |
| `/start?goal=reader&platform=web` | 200 | 0.78 s | yes | yes | Start building - QUL |
| `/requests` | 200 | 0.43 s | yes | yes | Resource requests - QUL |
| `/kits` | 200 | 0.32 s | yes | yes | Starter kits - QUL |
| `/kits/madani-reader` | 200 | 0.40 s | yes | yes | Madani reader - Starter kits - QUL |
| `/faq` | 200 | 0.38 s | yes | yes | FAQ - QUL |
| `/credits` | 200 | 0.49 s | yes | yes | Credits - QUL |
| `/tools` | 200 | 0.13 s | yes | yes | Contribution tools - QUL |
| `/changelog` | 200 | 0.24 s | yes | yes | Changelog - QUL |
| `/` | 200 | 0.53 s | yes | yes | Quranic Universal Library — Download Quran Data, JSON &amp; APIs |
| `/apps` | 200 | 0.14 s | yes | yes | Apps built with QUL |
| `/resources` | 200 | 0.46 s | yes | yes | Resources - QUL |

### Timing of the setup results and the docs search index

The results page (`/resources?goal=…`) builds one section per need, and one per need and language
for the needs that have languages. Each section searched a freshly loaded catalog, so the time
grew with the languages in the URL, which nothing caps. It now loads the catalog once per request
(see [Defects found](#defects-found-and-fixed)). Measured on the image, every goal, platform,
feature and script picked in the last two rows:

| Languages in the URL | Sections | Before the fix | After the fix | Response size |
| --- | --- | --- | --- | --- |
| 1 (one goal, one feature) | 1 | 0.50 s | 0.95 s | 77 KB |
| 2 | 21 | 2.91 s | 0.52 s | 336 KB |
| 94 (every language the step offers) | 481 | 46.95 s, 44.98 s | 4.85 s | 2.1 MB |

`/docs/search-index` (built per request): 83,074 bytes, 20,732 bytes gzipped, 0.4 to 2.4 s
across four requests under this load.

## Switch back

The image restarted once per setting, then `curl` on each URL. "page": an HTML `Accept` header.
"xhr": `X-Requested-With: XMLHttpRequest` with `Accept: */*`, as the old pages' help dialogs send
it. "fetch": `Accept: */*` only, as `fetch` sends it. Markers: "new" is the Inertia page
(`data-page="app"`), "old" a full page of the old layout, "fragment" the old layout-free answer
(no `<html>`), "empty" the empty 404 body that any unknown URL gets. `/docs/timestamp` is a key
only an ERB partial serves, so it stays old in every setting. The signed-out POST carries no
CSRF token: with `requests` on it is refused with 422, with it off the route does not exist.

| Request | URL | All six groups on | `content` off | `start` off | `requests` off | All three off (`home,catalog,apps`) | No groups |
| --- | --- | --- | --- | --- | --- | --- | --- |
| page | `/docs` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/docs/getting-started` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/docs/tutorial-recitation-end-to-end` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/docs/resource-translations` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/docs/murattal` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/docs/timestamp` | 200 old | 200 old | 200 old | 200 old | 200 old | 200 old |
| page | `/faq` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/credits` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/tools` | 200 new | 200 old | 200 new | 200 new | 200 old | 200 old |
| page | `/changelog` | 200 new | 404 empty | 200 new | 200 new | 404 empty | 404 empty |
| page | `/change_logs` | 301 -> /changelog | 200 old | 301 -> /changelog | 301 -> /changelog | 200 old | 200 old |
| xhr | `/docs` | 200 fragment | 200 fragment | 200 fragment | 200 fragment | 200 fragment | 200 fragment |
| xhr | `/docs/getting-started` | 200 fragment | 200 fragment | 200 fragment | 200 fragment | 200 fragment | 200 fragment |
| xhr | `/docs/murattal` | 200 fragment | 200 fragment | 200 fragment | 200 fragment | 200 fragment | 200 fragment |
| fetch | `/docs/getting-started` | 200 old | 200 old | 200 old | 200 old | 200 old | 200 old |
| page | `/start` | 200 new | 200 new | 404 empty | 200 new | 404 empty | 404 empty |
| page | `/kits` | 200 new | 200 new | 404 empty | 200 new | 404 empty | 404 empty |
| page | `/kits/madani-reader` | 200 new | 200 new | 404 empty | 200 new | 404 empty | 404 empty |
| page | `/resources?goal=reader&platform=web` | 200 new | 200 new | 200 new | 200 new | 200 new | 200 old |
| page | `/requests` | 200 new | 200 new | 200 new | 404 empty | 404 empty | 404 empty |
| page | `/requests?sort=date` | 200 new | 200 new | 200 new | 404 empty | 404 empty | 404 empty |
| POST (signed out) | `/requests` | 422 old | 422 old | 422 old | 404 empty | 404 empty | 404 empty |
| page | `/` | 200 new | 200 new | 200 new | 200 new | 200 new | 200 old |
| page | `/resources` | 200 new | 200 new | 200 new | 200 new | 200 new | 200 old |
| page | `/apps` | 200 new | 200 new | 200 new | 200 new | 200 new | 404 empty |

With `start` off (and in the all-three-off row) `/resources?goal=reader&platform=web` is the plain
catalog page (`Resources - QUL`), not the setup results (`Resources for your app - QUL`); with no
groups it is the old catalog. The request specs for both states of every group are part of the
full RSpec run in the [gate](#gate).

## Docs parity

For every key of `config/docs.yml` (30 keys, `DocsManifest.pages_in_order`), the image's page
load with `content` on and with it off, headings of the article (`h1` to `h6`, in order) compared:

```
content on:  30 keys: {200=>30} {"new, SSR"=>30}
content off: 30 keys: {200=>30} {"old"=>30}
30 keys; same non-empty headings in order: 30; different: []
headings compared: 239
```

`spec/requests/content/docs_spec.rb` (the parity spec: every key server-rendered with the old
headings, every tag page in the new layout, the XHR and `fetch` answers kept, both group states):
`21 examples, 0 failures`.

## Data replay on fresh clones

Two fresh clones of the snapshot (`CREATE DATABASE … TEMPLATE`, marked as clones), then the CMS
migrations the snapshot lacks, applied without dumping `db/schema.rb`:

```
qul_cms_content_validation: applied 13 pending CMS migrations
20261102100000 … 20261102160000 (seven draft_* tables), 20261110100000, 20261110100100,
20261110120000 (sprint 001), 20261112120000 CreateApps, 20261113120000 AddDirectoryFieldsToApps,
20261113200000 CreateResourceRequests
```

`bin/rails catalog:backfill` (the cutover order: before `start` is on), the same counts as sprint
001's replay:

```
blank_slugs: 1, display_names: 54, slugs: 538, related_links: 2, taggings: 21,
script_families: 53, renderings: 61, statuses: 2, requires_links: 36, recommended: 0,
summaries: 563, total: 1331 rows changed
```

The apps import twice, with an edit between the runs made through the model as the CMS form
saves it. The fingerprint is a SHA-256 over every App row's attributes and its icon's checksum:

```
$ bin/rails apps:import   # run 1
apps:import: 24 rows created
apps: 24 rows, 24 published, 24 with import_key, 16 icon attachments, max updated_at 2026-11-13T23:30:57.972312Z
sha256 of every row's attributes and icon checksum: 82e63145f8702610
quranwbw: QuranWBW | featured=true | published=true
$ edit quranwbw: name "QuranWBW (edited)", featured false (through the model, as the CMS form saves)
apps: 24 rows, 24 published, 24 with import_key, 16 icon attachments, max updated_at 2026-11-13T23:31:10.644688Z
sha256 of every row's attributes and icon checksum: 9747d1eb061a37d0
quranwbw: QuranWBW (edited) | featured=false | published=true
$ bin/rails apps:import   # run 2
apps:import: 0 rows created
apps: 24 rows, 24 published, 24 with import_key, 16 icon attachments, max updated_at 2026-11-13T23:31:10.644688Z
sha256 of every row's attributes and icon checksum: 9747d1eb061a37d0
quranwbw: QuranWBW (edited) | featured=false | published=true
```

Run 2 created nothing and changed nothing: the same row count, the same latest `updated_at` and
the same fingerprint, and the edited name and featured flag stayed. Eight entries of
`config/apps.yml` have no icon file, so 16 icons for 24 rows.

## Write paths on the running image

`curl` against the image with all groups on, as Inertia sends its requests (`X-Inertia`, JSON,
the `X-XSRF-TOKEN` header from the cookie). Signed in as the fake reader account (Devise's sign-in
form). Row counts from the scratch clone; "redis keys" lists every key in the image's Redis, where
Sidekiq jobs would be queued.

```
== before
rows: requests=0 (open, visible: 0) votes=0 apps=24 (unpublished: 0)
redis keys: []
== anonymous
  POST /requests (Inertia)
    HTTP/1.1 409 Conflict
    x-inertia-location: /users/sign_in?user_return_to=%2Frequests
  POST /requests (plain form post)
    302 -> http://localhost:3001/users/sign_in?user_return_to=%2Frequests
  POST /apps (Inertia)
    HTTP/1.1 409 Conflict
    x-inertia-location: /users/sign_in?user_return_to=%2Fapps%3Fsubmit%3D1
rows: requests=0 (open, visible: 0) votes=0 apps=24 (unpublished: 0)
== signed in (reader)
    sign in as 302 -> http://localhost:3001/
  POST /requests
    HTTP/1.1 302 Found
    location: http://localhost:3001/requests
rows: requests=1 (open, visible: 1) votes=0 apps=24 (unpublished: 0)
  invalid POST /requests (no title)
    HTTP/1.1 302 Found
    location: http://localhost:3001/requests
rows: requests=1 (open, visible: 1) votes=0 apps=24 (unpublished: 0)
== votes on the new request
  anonymous POST /requests/:id/vote
    HTTP/1.1 409 Conflict
    x-inertia-location: /users/sign_in?user_return_to=%2Frequests
rows: requests=1 (open, visible: 1) votes=0 apps=24 (unpublished: 0)
  reader POST /requests/:id/vote
    HTTP/1.1 302 Found
    location: http://localhost:3001/requests
rows: requests=1 (open, visible: 1) votes=1 apps=24 (unpublished: 0)
  reader POST /requests/:id/vote again
    HTTP/1.1 302 Found
    location: http://localhost:3001/requests
rows: requests=1 (open, visible: 1) votes=1 apps=24 (unpublished: 0)
== app submission (reader, no icon: production storage)
  POST /apps
    HTTP/1.1 302 Found
    location: http://localhost:3001/apps
rows: requests=1 (open, visible: 1) votes=1 apps=25 (unpublished: 1)
== after
redis keys: []
log lines naming a job or a mail: 0
```

- Anonymous: a request, a vote and an app submission are each refused (Inertia: 409 to sign-in
  with the return path; a plain form post: 302 to sign-in) and change no row.
- Signed in: one request row, `open` and visible; invalid input (no title) adds none; the first
  vote adds one row and the second changes nothing; an app submission adds one unpublished row.
- Nothing enqueued or mailed: Redis held no key before or after, and `log/production.log` has no
  line naming a job or a mail.

The named request specs (`spec/requests/requests/writes_spec.rb`,
`spec/requests/site/app_submissions_spec.rb`, `spec/requests/cms/*`) cover the same rules plus
the daily limits, CSRF and the hidden and missing cases, in the [gate](#gate)'s RSpec run.

## Icon upload

Production stores app icons on the `qul_exports` service, which needs the production storage
credentials, so the image cannot store one and the app submission above was sent without an
icon. The upload was proven on the local disk service: Rails in development on the scratch
clones, where `apps.spec.ts` "a signed-out visitor sees it disabled, signs in, comes back to it
and submits with an icon" passed at both widths (see the suite below). The row it left:

```
storage service in development: local, App icon service: nil
published=false icon=true service=local type=image/png bytes=7546 file_on_disk=true
```

The byte checks (type from the file's bytes, at most 1 MB) are covered by the RSpec app
submission specs. **Human step:** after cutover, submit an app with an icon on production and
check that the icon is stored on `qul_exports` and shows in the CMS.

## Full browser suite

`yarn test:browser --workers=2 --timeout=120000`, every page group on, desktop (1280 px) and
phone (Pixel 7). Rails in development in the Ruby container on the scratch clones (local disk
storage, which the icon tests need), Vite on the host, `QUL_BROWSER_RAILS_RUNNER` pointing at the
same clones. The specs sign in as the fake reader and admin accounts and run anonymous.

```
Running 246 tests using 2 workers
  21 skipped
  225 passed (12.4m)
```

All 246 provenance lines say `real backend` or `mixed` with the routes they stub; every test that
ran passed on the first try, with no retry. Per spec:

| Spec | Desktop passed | Phone passed | Skipped |
| --- | --- | --- | --- |
| `apps.spec.ts` | 6 | 6 | 0 |
| `bundle.spec.ts` | 2 | 2 | 2 |
| `card-previews.spec.ts` | 2 | 2 | 0 |
| `catalog-search.spec.ts` | 13 | 12 | 3 |
| `catalog-views.spec.ts` | 3 | 3 | 0 |
| `catalog.spec.ts` | 4 | 4 | 0 |
| `changelog.spec.ts` | 2 | 2 | 0 |
| `content-pages.spec.ts` | 3 | 3 | 0 |
| `docs.spec.ts` | 8 | 9 | 1 |
| `home-library.spec.ts` | 5 | 5 | 0 |
| `home-no-webgl.spec.ts` | 1 | 1 | 0 |
| `home.spec.ts` | 4 | 4 | 0 |
| `kits.spec.ts` | 4 | 4 | 0 |
| `look.spec.ts` | 0 | 0 | 2 |
| `previews.spec.ts` | 10 | 7 | 3 |
| `requests.spec.ts` | 6 | 6 | 0 |
| `resource-cards.spec.ts` | 16 | 16 | 0 |
| `resource-page.spec.ts` | 7 | 6 | 3 |
| `shell.spec.ts` | 8 | 5 | 5 |
| `start.spec.ts` | 7 | 7 | 0 |
| `type-pages.spec.ts` | 5 | 5 | 2 |

The skips are by design: width-specific tests, the sweeps (desktop only), `look.spec.ts` without
`LOOK_PATH`, and the public-mode download tests. Those ran in a second run with the server in
`QUL_DOWNLOAD_MODE=public` (`bundle.spec.ts` and `resource-page.spec.ts`): 18 passed, 4 skipped
(the sign-in-mode tests), including "in public mode a tray download sends the file" and "public
mode › Download sends the file without sign-in" at both widths.

### This sprint's pages against the production image

The specs of this sprint's pages and the shell (`docs`, `content-pages`, `changelog`, `start`,
`kits`, `requests`, `shell`) also ran against the image (production build, SSR service, all
groups on), `--workers=2`: 71 passed, 6 skipped (by design), 1 failed and the 2 tests after it in
the same serial block did not run. The failure was desktop `requests.spec.ts` "invalid input
shows the errors…": the dialog was still sending (its Send button disabled) when the 5-second
expectation ended, on an emulated `amd64` container at load average 200+; the same test passed at
phone width in that run and on the development server. `requests.spec.ts` at desktop, rerun
alone against the image: 6 passed.

## Link sweep

`shell.spec.ts` "every header and footer link: old pages load in full with 200, new pages are
Inertia visits, and the only old pages are contributor tools" follows every link of the header
menus, the footer and the spotlight's "Browse all resources", with every group on. It passed on
the development server and against the image, with the same result:

```
[links] 87 links, 61 Inertia visits, all 200; old pages: /translations /transliterations /tafsirs
/surah_infos /mushaf_layouts /tajweed_words /word_texts /surah_audio_files /ayah_audio_files
/gapless-ayah-extractor /word_translations/select_resource /word_transliterations
/arabic_transliterations /word_roots /word_concordance_labels /morphology/dependency-graphs
/morphology_phrases /similar_ayahs /topics /ayah_themes /quran_scripts_comparison /compare-font
/compare-audio /compare_ayah /community/chars_info
```

Every old page in the list is a contributor tool of the Contribute menu
(`ToolsHelper#developer_tools`), or the translation tool the Resources menu links as "Fix a
translation" (`/translations`); the test fails on any other. The remaining old pages a new page
links to are sign-in (the account control, outside the menus) and the CMS, which no menu or
footer link opens. No content page (docs, FAQ, credits, tools overview, changelog) is old.

## Defects found and fixed

Both are in this sprint's new code, not on the live site, and were fixed in this story with a
request spec seen failing first.

- **Setup results loaded the catalog once per section.** `Start::SetupController#results` ran a
  full `Catalog::SearchQuery` (which loads every published resource) for each section, and once
  more for the language list. `Catalog::SearchQuery` now takes the `rows` of a query already
  loaded, and the results page loads the catalog once and searches it for every section. Spec
  `spec/requests/start/setup_spec.rb` "loads the catalog once, however many languages are picked"
  (resources instantiated for 1 and for 8 languages): red `expected: 2188, got: 13675`, then
  green. Times are in [Timing](#timing-of-the-setup-results-and-the-docs-search-index).
- **Card previews wrote the session cookie back.** Every preview response (`/resources/:type/:slug/preview`,
  fetched while a page loads) re-sent the visitor's session cookie. A preview that answered after
  the sign-in page could put back the session without the sign-in return path, the case 002-19
  saw. `Catalog::PreviewsController` now skips the session write. Spec
  `spec/requests/catalog/card_previews_spec.rb` "leaves the session cookie of a visitor who has
  one alone": red (`Set-Cookie: _quran_com-community_session=…`), then green. On the image, a
  preview request sent with a session cookie answers with no `Set-Cookie`:

  ```
  HTTP/1.1 200 OK
  cache-control: max-age=3600, private
  ```

## Gate

The repo-wide gate ran green at `252ed82c` (the driver's checkpoint: standalone 245, RuboCop 143
files, `tsc`, ESLint, Prettier, RSpec 505/0, Vitest 444). This story changed four Ruby files and
two request specs, no frontend file. Its Ruby steps rerun on the result, in the Ruby container:

```
$ RUBYOPT=-rbundler/setup ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |f| require File.expand_path(f) }'
245 runs, 719 assertions, 0 failures, 0 errors, 0 skips
$ git diff -z --name-only --diff-filter=d $(git merge-base origin/qul-next HEAD) -- '*.rb' '*.rake' | xargs -0 -r bundle exec rubocop --force-exclusion
143 files inspected, no offenses detected
$ bin/rails typelizer:check
Generated TypeScript types and route helpers are up to date.
$ VITE_RUBY_AUTO_BUILD=false bundle exec rspec
Finished in 3 minutes 12.5 seconds (files took 2.46 seconds to load)
507 examples, 0 failures
```

## Human steps and what this run did not cover

- **Production storage:** submit an app with an icon after cutover and check the icon is stored
  on `qul_exports` ([Icon upload](#icon-upload)). Removing an app with an icon in the CMS enqueues
  a purge job, which production's Sidekiq runs.
- **Cutover order:** run the migrations, `bin/rails catalog:backfill` before `start` is on, and
  `bin/rails apps:import` once after the migrations and before `home` or `apps` serves traffic;
  never run the import again after editors remove apps.
- **Maintainers:** agree to the `apps` columns and the two request tables; the requests list needs
  a design look.
- The image ran on clones of the 2026-11-02 snapshot, emulated on one heavily loaded machine: no
  production traffic, database or runtime configuration (storage, Sentry, the page group and
  download mode values). Times are upper bounds from that machine.
- Not verified on a real phone (Pixel 7 emulation only).
- The results page still grows with the languages picked (481 sections and 2.1 MB for all 94);
  the setup step does not cap them. A cap is a design choice for the setup's language step.
