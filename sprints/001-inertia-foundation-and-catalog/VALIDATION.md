# Sprint 001 validation

Story 001-18, run on 2026-11-10 from `sprint/001-inertia-foundation-and-catalog` at `a41e5339`
(001-17 plus its checkpoint record), with the two browser-test fixes below on top. Everything ran
on one development machine: the production image in Docker (`linux/amd64`, as production
builds), Rails for specs and runner scripts in the `ruby:3.3.10` container, Playwright and Vite
on the host. Every database was a local clone of the 2026-11-02 snapshot, or a fresh restore of
the same backups into new, scratch databases (dropped afterwards). No production credential,
master key, SMTP setting or Sidekiq process was used.

This file is public. It holds catalog counts only: no download numbers, nothing from user,
download, draft or admin tables, and no connection details.

## Exit criteria

| PRD exit criterion | Result | Evidence |
| --- | --- | --- |
| With all three page groups on, every in-scope URL returns server-rendered HTML with correct meta tags | pass | [Production image](#production-image-and-ssr): seven URLs with the SSR marker and their titles; [detail sweep](#detail-sweep-in-the-production-image): 547 of 547 detail pages server-rendered; [browser suite](#full-browser-suite) against the image; head request specs (full RSpec 269/0 at `2fed56b4`, 001-17) |
| With all page groups off, every old URL behaves as on main | pass | [Switch back](#switch-back): each group removed, then all; the old-page request specs from 001-01 and every `page_groups: []` group pass |
| Every published resource has a detail page that returns 200 with a preview or an explicit "no preview" state | pass | [Detail sweep](#detail-sweep-in-the-production-image) in the image (547/547), and the 001-14 sweep spec in RSpec (full suite 269/0 at `2fed56b4`); the browser layout, font and script sweeps pass against the image |
| The production image builds locally and serves SSR; stopping SSR degrades to client rendering | pass | [Production image](#production-image-and-ssr) and [SSR failure and recovery](#ssr-failure-and-recovery) |
| Migrations plus backfills replay on a fresh restore, and a second backfill run changes nothing | pass | [Backfill replay](#backfill-replay-on-a-fresh-restore): run 2 total 0, hand edits kept |
| The download rules hold in both modes on both routes | pass | [Download rules](#download-rules): `spec/requests/catalog/downloads_spec.rb` 44 examples, 0 failures; the browser download tests pass against the image in each mode |
| The generated-types check, request specs, component tests and browser tests pass from one gate command | pass at `2fed56b4`; rerun owed by the driver | The 001-17 gate: full RSpec 269/0, Vitest 239, typecheck, ESLint, Prettier and `typelizer:check` clean. This story changed two browser specs only (lint, format and `tsc -p spec/browser` clean); the driver's checkpoint run and 001-20's handoff quote the final gate |
| The review report is generated and lists every drafted value | pass | [Review report](#review-report): 695 rows = 695 drafted entries by direct query, on the fresh restore |
| The sprint branch is merged into `qul-next`, `qul-next` is pushed with a draft PR open against `main`, and the handoff lists the human steps | open, owner 001-20 | Not part of this story. The stack layers 1 to 5 are open as draft PRs and green in CI |
| `main` is unchanged, and no production data, generated report or private note is committed | pass | [Repository checks](#repository-checks) |

## Production image and SSR

`docker build --platform linux/amd64 --progress=plain -t qul-sprint001:validation .` exited 0.
The gem and package layers came from the cache; everything from `ADD . /home/app/qul/` on was
built fresh, including both `assets:precompile` runs. Log tail:

```
#43 51.41 Build with Vite complete: /home/app/qul/public/vite
#43 DONE 52.1s
#44 [40/44] RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
#44 DONE 37.2s
...
#49 writing image sha256:4591b5381e2156fdf5be7778b9c3582bba72900f3ab30a66e95135b104da2c30 done
#49 naming to docker.io/library/qul-sprint001:validation done
build exit 0
```

The SSR build in the same step wrote `public/vite-ssr/ssr.mjs` and one chunk per page
(`HomePage`, `CatalogPage`, `TypePage`, `ResourcePage`, `AppsPage`, …).

The container ran on the development clones with `SECRET_KEY_BASE` only (no master key), the
Sidekiq service disabled by a mounted `down` file, no SMTP values, and
`QUL_PAGE_GROUPS=home,catalog,apps`. `sv status`: `down: sidekiq`, `run: inertia-ssr`,
`run: nginx`. The process list had Passenger (`PassengerAgent watchdog`, `PassengerAgent core`, two
`rack-preloader.rb` app processes), `node … public/vite-ssr/ssr.mjs`, redis and memcached, and
only the `runsv sidekiq` supervisor (no Sidekiq process).

`curl` of each URL. SSR: the HTML has `data-server-rendered="true"` on `#app`. Inertia: the HTML has
the `data-page="app"` script.

| URL | Status | Time | SSR | Inertia | `<title>` |
| --- | --- | --- | --- | --- | --- |
| `/` | 200 | 0.28 s | yes | yes | Quranic Universal Library — Download Quran Data, JSON &amp; APIs |
| `/resources` | 200 | 0.33 s | yes | yes | Resources - QUL |
| `/resources/tafsir` | 200 | 0.16 s | yes | yes | Tafsirs - QUL |
| `/resources/translation/hindi-wbw-translation` | 200 | 0.30 s | yes | yes | Hindi wbw translation - Translation - QUL |
| `/resources/mushaf-layout/kfgqpc-nastaleeq-15-lines-layout` | 200 | 0.23 s | yes | yes | KFGQPC Nastaleeq 15 lines layout - Mushaf layout - QUL |
| `/resources/recitation/abdur-rahman-as-sudais-recitation` | 200 | 0.15 s | yes | yes | Abdur-Rahman as-Sudais Recitation - Recitation - QUL |
| `/apps` | 200 | 0.08 s | yes | yes | Apps built with QUL |

## SSR failure and recovery

`sv stop inertia-ssr`, then `sv start inertia-ssr`, in the running container (no Passenger
restart). "Browser" is headless Chromium loading the page with JavaScript on. It records whether
`#app` was server-rendered, the page's `<h1>` once React has rendered, and any page or console
error. GA4 and the GitHub API were blocked. The Sentry loader was not.

| URL | Before: status, SSR | During: status, SSR | During: browser h1, errors | After: status, SSR | After: browser, errors |
| --- | --- | --- | --- | --- | --- |
| `/` | 200, yes | 200, no | "Verified data for builders impacting the Ummah.", none | 200, yes | server-rendered, hydrated, none |
| `/resources` | 200, yes | 200, no | "Resources 547", none | 200, yes | server-rendered, hydrated, none |
| `/resources/tafsir` | 200, yes | 200, no | "Tafsirs 108", none | 200, yes | server-rendered, hydrated, none |
| `/resources/translation/hindi-wbw-translation` | 200, yes | 200, no | "Hindi wbw translation", none | 200, yes | server-rendered, hydrated, none |
| `/resources/mushaf-layout/kfgqpc-nastaleeq-15-lines-layout` | 200, yes | 200, no | "KFGQPC Nastaleeq 15 lines layout", none | 200, yes | server-rendered, hydrated, none |
| `/resources/recitation/abdur-rahman-as-sudais-recitation` | 200, yes | 200, no | "Abdur-Rahman as-Sudais Recitation", none | 200, yes | server-rendered, hydrated, none |
| `/apps` | 200, yes | 200, no | "Apps built with QUL 24", none | 200, yes | server-rendered, hydrated, none |

While SSR was down the server-managed `<title>` stayed in the HTML (same titles as above), and
`log/production.log` logged one line per request:

```
ERROR -- : [<request id>] [inertia-rails] SSR render failed: Failed to open TCP connection to localhost:13714 (Connection refused - connect(2) for "localhost" …
```

## Detail sweep in the production image

Every published resource's detail URL (`/resources/<type>/<slug or id>`, 547 rows from the
development clone) requested from the running image with all groups on:

```
swept 547: 547 200 with SSR, 0 200 without SSR, 0 other
```

That covers 14 types: translation 204, recitation 133, tafsir 108, quran-script 30, font 26,
mushaf-layout 12, transliteration 10, quran-metadata 8, morphology 6, surah-info 6, and one each
of ayah-theme, ayah-topics, mutashabihat and similar-ayah. The rows with known data errors are
included. The 001-14 sweep spec, which also checks the preview or no-preview state, is part of
the full RSpec run (269/0 at `2fed56b4`).

## Full browser suite

`yarn test:browser --workers=4` with `QUL_BROWSER_BASE_URL` pointing at the production image
(all groups on) and `QUL_BROWSER_RAILS_RUNNER='docker exec qul-dev bin/rails runner'` (same
development clone as the image). Projects: desktop (1280 px) and phone (Pixel 7). The specs sign
in as the fake reader and admin, and run anonymous. The download-mode tests run only against a
server in that mode, so the suite ran once per mode, with the container restarted with
`QUL_DOWNLOAD_MODE=public` for the second.

| Mode | Desktop passed / skipped | Phone passed / skipped | Failed | Total |
| --- | --- | --- | --- | --- |
| sign-in (default) | 47 / 5 | 39 / 12 | 1, passed on rerun | 86 passed, 17 skipped, 1 failed |
| public | 47 / 5 | 41 / 11 | 0 | 88 passed, 16 skipped |

The skips are by design: width-specific tests, the sweeps (desktop only), the other mode's
download tests and `look.spec.ts` without `LOOK_PATH`.

Results that needed a fix or a rerun:

- First sign-in run: 85 passed, 2 failed.
  - `previews.spec.ts` layout sweep failed twice in a row, on a different page each time (a
    bismillah font, then a surah-name font, reported not loaded). The page's
    `data-font-status` covers its text font only, and the check ran before the decoration fonts
    had loaded. Fix: the check now calls `document.fonts.load` for each named font before
    `document.fonts.check` (a font that cannot load still fails). After the fix the whole file
    passed (10 passed), and the public and later sign-in runs passed it.
  - `catalog.spec.ts` "a new page links out to an old page" failed in both full sign-in runs and
    passed alone. The card link is a full page load. The test read the new document right after
    the URL changed, before that document had loaded. Fix: wait for the load state before the
    check. After the fix it passed 10 of 10 (`--repeat-each=5`, both widths) and in the third
    full run.
- Third sign-in run (the one in the table): one failure, `home.spec.ts` "animates the ring …"
  (phone). The predicate timed out after 15 s, a timing flake seen before under load. It passed
  alone on rerun.

## Backfill replay on a fresh restore

Both 2026-11-02 backups restored with `psql` into new databases on the snapshot server, never
over the working snapshot: CMS in about 3 minutes, content after it, no `ERROR` lines. Before
migrating, the CMS restore had 118 schema migrations up to `20261023140000`, and no
`display_name` or `review` column. Rails (development, in the Ruby container) pointed at the
restore through `QUL_CMS_CONTENT_DB_NAME` / `QUL_QURAN_CONTENT_DB_NAME`.

Migrate (`migration_context.migrate`, as `bin/snapshot-clones` does, so `db/schema.rb` was not
dumped; `git status db/` stayed clean):

```
databases: qul_cms_replay, qul_quran_replay
== 20261102100000 CreateDraftTopics: migrated
… (six more draft_* tables from main)
== 20261110100000 AddCatalogFieldsToDownloadableResources: migrated (0.0478s) =
== 20261110100100 AddRelationTypeToDownloadableRelatedResources: migrated (0.0100s)
== 20261110120000 AddAnonymousDownloadCountToDownloadableFiles: migrated (0.0055s)
applied 10 pending CMS migrations: 20261102100000, …, 20261110100000, 20261110100100, 20261110120000
```

Backfill run 1 (`bin/rails catalog:backfill`):

```
blank_slugs: 1 rows changed
display_names: 54 rows changed
slugs: 538 rows changed
related_links: 2 rows changed
taggings: 21 rows changed
script_families: 53 rows changed
renderings: 61 rows changed
statuses: 2 rows changed
requires_links: 36 rows changed
recommended: 0 rows changed
summaries: 563 rows changed
total: 1331 rows changed
```

These are the same counts 001-07 (616) and 001-08 (715) recorded on the development clone.

Hand edits between the runs, made through the model as the CMS form saves them:
`tafsir-ibn-kathir-arabic` short summary (a drafted value),
`kfgqpc-nastaleeq-15-lines-layout` script family (a drafted value, changed to another family)
and `hindi-wbw-translation` display name. The model moved both drafted fields to `reviewed`.

Backfill run 2:

```
blank_slugs: 0 rows changed
display_names: 0 rows changed
slugs: 0 rows changed
related_links: 0 rows changed
taggings: 0 rows changed
script_families: 0 rows changed
renderings: 0 rows changed
statuses: 0 rows changed
requires_links: 0 rows changed
recommended: 0 rows changed
summaries: 0 rows changed
total: 0 rows changed
```

After run 2, all three hand-edited values were still in place: the summary text, the changed
script family and the display name.

Also checked: an edit made in SQL, outside the model, to a drafted summary. The next run reported
`summaries: 1 rows changed` (it moved that key from `drafted` to `reviewed`), the SQL value was
kept, and the run after that reported `total: 0 rows changed`.

## Switch back

The image restarted once per setting, curl on each URL. "new": the Inertia page answers. "old":
the old ERB layout with Turbo answers. `/apps` has no old page on main, so with `apps` off it is a
404, as on main.

| `QUL_PAGE_GROUPS` | `/` | `/resources` | `/resources/tafsir` | `/resources/translation/hindi-wbw-translation` | `/apps` |
| --- | --- | --- | --- | --- | --- |
| home,catalog,apps | 200 new | 200 new | 200 new | 200 new | 200 new |
| catalog,apps (home off) | 200 old | 200 new | 200 new | 200 new | 200 new |
| home,apps (catalog off) | 200 new | 200 old | 200 old | 200 old | 200 new |
| home,catalog (apps off) | 200 new | 200 new | 200 new | 200 new | 404 |
| (none) | 200 old | 200 old | 200 old | 200 old | 404 |

With no groups set, the old-page request specs from 001-01 (`spec/requests/resources_spec.rb`):

```
Resources catalog (old page)
  lists the published resource types
  still finds a resource by its old numeric id after the slug backfill
2 examples, 0 failures
```

Every `page_groups: []` example group (detail, shell, downloads on both routes, previews,
catalog and type pages): `7 examples, 0 failures`.

## Truth on real data

The image's props (the `data-page` JSON of `/` and `/resources`) against direct queries on the
development clone. CMS aggregates are in SQL. The language counts read the CMS rows' language,
else their content row's, from the content database, combined outside SQL because the two
databases cannot be joined. The popular order is compared by resource id; no download number is
written here.

| Check | Page | Direct query | Result |
| --- | --- | --- | --- |
| Home: resources | 547 | 547 | pass |
| Home: languages | 94 | 94 | pass |
| Home: recitations | 133 | 133 | pass |
| Home: category counts sum to resources | 547 | 547 | pass |
| Facet type = tafsir | 108 | 108 | pass |
| Facet language = en | 39 | 39 | pass |
| Facet script = madani | 27 | 27 | pass |
| Facet granularity = 1_ayah | 237 | 237 | pass |
| Facet status = legacy | 1 | 1 | pass |
| Popular sort: top ten, in order (first page of `/resources?sort=popular` against the published-file download totals per resource) | ten ids | ten ids | pass (identical order; no tie between 10th and 11th) |

## Download rules

`spec/requests/catalog/downloads_spec.rb`, on the test clones: `44 examples, 0 failures`. It
covers the slug URL and the old token URL, each in sign-in and public mode: unpublished file and
unpublished resource (404 for everyone), restricted (blocked for anonymous and normal users,
file for an admin), anonymous (sign-in and back, or the file with the anonymous count +1),
signed-in (per-user row), HEAD (counts nothing), no cookie for anonymous downloads, noindex and
`robots.txt`. In the browser, the sign-in chain (sign-in mode) and the public-mode download pass
against the image.

## Review report

`bin/rails catalog:review_report[tmp/replay-review-report.md]` on the fresh restore after the
replay: `695 drafted values`. Direct count of `drafted` keys over `downloadable_resources.review`
on the same database: 695. That is the 698 that 001-08 recorded, less the three values hand-edited
above, which are now reviewed. The file was deleted after counting and was never committed.

## Repository checks

```
$ git fetch origin
$ git log --oneline main..origin/main | wc -l
24          # the local main is behind; origin/main is 3d805f64
$ git log --oneline HEAD..origin/main | wc -l
0           # origin/main is the sprint's merge base, 3d805f64
$ git merge origin/main           # trial, on a scratch branch
Already up to date.
$ git diff $(git merge-base origin/main HEAD) --stat -- app/views/layouts/application.html.erb app/javascript
            # empty, exit 0
$ git ls-files tmp | wc -l
0
$ git ls-files | grep -iE '\.(sql|dump|bz2|gz|zip|sqlite3?|db)$|playwright-report|catalog-review-report'
            # nothing
$ git log --oneline origin/main..main | wc -l
0           # no commit on main
```

`main` is unchanged: `origin/main` is still `3d805f64`, the commit `qul-next` was cut from.

Conflicts the cutover will meet. `origin/main` has not moved, so it adds none. The unmerged
qiraat stack will: a trial merge of `origin/qiraat/p7-5-drop-legacy` (its top) into the sprint
branch stopped with 30 conflicting files. Merging it into `origin/main` alone gives 29 of them,
from main's own changes since the stack was cut (contributor tools, proofreading renames,
`config/database.yml`, …). The sprint adds one: `.gitignore`. Of the files both the sprint and
the stack change, `config/routes.rb` and `db/schema.rb` conflict either way, and `Gemfile`,
`Gemfile.lock`, `.rspec`, `spec/spec_helper.rb` and `app/models/downloadable_resource.rb` merge
cleanly.

```
.gitignore                                   (sprint and stack)
config/routes.rb                             (main and stack; the sprint also edits it)
db/schema.rb                                 (main and stack; the sprint also edits it)
config/database.yml
app/admin/audio/audio_recitation.rb
app/controllers/surah_audio_files_controller.rb
app/controllers/tafsir_proofreadings_controller.rb        (modify/delete)
app/controllers/translation_proofreadings_controller.rb   (modify/delete)
app/controllers/word_translations_controller.rb
app/models/audio/segment.rb
app/models/qirat_type.rb                                  (modify/delete)
app/models/qul_quran_record.rb
app/models/tafsir.rb
app/presenters/segments/reciter_presenter.rb              (modify/delete)
app/presenters/translation_presenter.rb
app/presenters/word_translations_presenter.rb
app/services/audio/segment_validator.rb
app/views/resources/previews/_font.html.erb
app/views/shared/_page_font.html.erb
app/views/tafsirs/index.html.erb
app/views/tafsirs/show.html.erb
app/views/translation_proofreadings/_ayah_view.html.erb   (modify/delete)
app/views/translations/index.html.erb
app/views/translations/show.html.erb
app/views/word_texts/show.html.erb
app/views/word_translations/_word_translation_field.html.erb
app/views/word_translations/index.html.erb
app/views/word_translations/new.html.erb
app/views/word_translations/show.html.erb
lib/audio_segment/tarteel.rb
```

## Not covered here

- The final gate run after this story's two spec fixes belongs to the driver's checkpoint and
  to 001-20, as do the `qul-next` merge, the push and the PR.
- The image ran on the development clones, not on production-sized traffic or the production
  database. The production runtime configuration (storage, SMTP, Sentry, the page group and
  download mode values) is for cutover.
