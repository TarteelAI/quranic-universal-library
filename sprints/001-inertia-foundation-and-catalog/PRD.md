# Sprint PRD: 001-inertia-foundation-and-catalog

## Purpose / Why Now

The redesigned QUL site (prototype v7) is approved, and a data audit shows what the catalog needs. The new site is built inside this Rails app as Inertia.js + React pages, beside the ERB, Turbo, Stimulus and Vue pages, which keep working. This sprint lays that foundation and ships the pages most visitors use: the home page, the resource catalog, the 14 type pages, the resource detail page with real previews and downloads, and the apps directory. It unlocks the next sprint (docs, developers page, public API, MCP server) and the later rebuild of the contributor tools in the same Inertia app.

## Context

Paths that start with `../` are sibling folders on the team's machines. They are local to the team and are never committed here.

- `../qul-redesign/ds/`: the approved v7 design. Components, tokens and pages to port. Hash routing, mock data and in-memory state are prototype shortcuts, not design.
- `../qul-redesign/brief.md`: information architecture. Its sitemap is wider than this sprint.
- `../qul-redesign/research/data-requirements.html`: the data gap table behind the catalog data changes.
- `../qul-redesign/research/apps-using-qul.md`: sourced list of apps for the apps directory.
- `../qul-redesign/research/api-spec.html`: next sprint's API proposal. Read it only to keep this sprint's query objects and serializers reusable. It sends interactive widgets to an API; this sprint uses Inertia props for them (see Ralph Notes).
- `../qul-data/audit-2026-11-02.md`: aggregate facts about the catalog data. Required reading before any backfill.
- The design review comments #11, #20, #21, #22, #23, #24 and #25 on prototype v7 (team drop). All seven are owned here; each is restated in the story that owns it.
- This repo: no Vite, React, Inertia, Alba or `spec/` exists. Planning facts were checked at main `30bec50e`; `qul-next` is cut from main `3d805f64`, 24 commits later (see `lessons.md`).
- `lessons.md` in this folder: local setup rules, build traps and catalog data facts.
- The private sprint notes (team drop): facts that do not belong in a public repo. Stories that need them say so.

## Terms

- **Page group**: a set of URLs that switch together between the old ERB pages and the new Inertia pages. Groups in this sprint: `home`, `catalog` (`/resources` and below), `apps`.
- **Page group setting**: one deploy-time setting that lists the page groups served by the new pages. A group that is not listed is served by the old views, which stay in the code.
- **Drafted value**: a field value written by a backfill through inference, not by a person.
- **Review column**: one column on the resource row that records which fields hold drafted values, when they were written and by which backfill.
- **Review report**: a generated file that lists every drafted value and the known data errors, for the data team. It is generated on demand and is not committed.
- **Download mode**: one setting with two values. `sign_in`: Rails asks for sign-in, then sends the file. `public`: no account is needed.
- **Display name**: a name that is unique inside a resource type, built from existing fields. The editor's `name` is never overwritten.
- **Script family**: `madani`, `indopak` or `other`. Named `script_family` because the unmerged qiraat work uses "script" for one riwayah in one encoding.

## In-Scope Outcomes

Foundation
- Inertia pages (React 19, TypeScript, Vite, Tailwind 4) run in this app with their own layout and source tree. Every existing page, bundle and layout works as before.
- Server-side rendering is on. When the SSR process is down or slow, pages render in the browser and the failure is reported.
- Data shapes are defined once as Alba serializers. TypeScript types and route helpers are generated from Rails. A gate check fails when generated files are stale.
- Three test layers exist and run with one command each: request specs on a clone of the snapshot, component tests, and browser tests against real Rails.
- The production Docker image builds with the new front end and runs the SSR process as a service.
- Pushes and pull requests to `qul-next` and sprint branches run a CI workflow with the checks that need no database. Request specs and browser tests run locally.
- New pages take over existing URLs through the page group setting. Turning a group off restores the old page with no code change.
- New pages keep what the old pages provide: title, description, Open Graph and Twitter tags, canonical URL, JSON-LD, GA4 page views on every visit, browser and server error reporting, correct 404 status, and the return to the same page after sign-in.

Catalog data (CMS database only)
- Each resource has a lifecycle status with a superseded-by pointer, a unique slug and a display name. Script, font and layout resources have a script family and a rendering method. Related-resource links have a relation type.
- The duplicate link, the orphaned link and the orphaned taggings are removed.
- Backfills infer status, script family, rendering, requires-links and one-line summaries as drafted values, recorded in the review column. A task marks drafted values as reviewed; CMS form changes are deferred.
- Every data change is a migration plus an idempotent backfill that replays on a newer copy of the data.
- The review report is generated on demand.

Downloads
- One download route with these rules: 404 for an unpublished file or resource; a restricted resource is blocked for everyone except admins. The existing download URL follows the same rules.
- Both download modes work. The default in this sprint is `sign_in`.
- Every download is counted. An anonymous download counts once per visitor per file per day, where the visitor is a random first-party cookie and the request's address is not used. A signed-in download still writes the per-user row. Existing totals are kept. Popular sorting reads the combined total.

Pages (all server-rendered, on real data)
- Site shell: v7 header and footer with comments #21, #22, #24 and #25 applied, signed-in state, flash messages, and plain links to the pages not rebuilt yet.
- Catalog `/resources`: search that matches Arabic text; filters for type, language, script family (several at once, #20), format, granularity and status; facet counts; three sorts; a shareable URL for every view; a filter drawer on phones; a request-a-resource card. A ⌘K spotlight searches resources from any new page.
- Type pages for all 14 types: description, cards, "Which one should I pick?" where status data exists, and a comparison table for layouts, fonts and scripts.
- Resource detail for every type: header, files panel with Download, "Works with", Preview, Data, Licence and Changelog tabs, and a report-an-issue link. Old id URLs redirect to the slug URL.
- Real previews, loaded per page or per surah: mushaf pages (unicode and glyph-per-page), font and script samples, recitation audio with ayah highlighting, surah text for translations, tafsirs and transliterations, and a bounded record sample for every other type.
- Home page from v7 with #23 applied, on real numbers.
- Apps directory from v7 with #11 applied, with a way to submit an app.

## Explicit Non-Goals

- Docs pages, the developers page, the public API, the MCP server, `/resources.json` and `llms.txt`. No public API contract is built or promised.
- The wizard (`/start`), kits, the bundle tray, requests, the changelog page, account pages, i18n and a language selector.
- Rebuilding contributor tools, sign-in pages or the CMS in React. No Inertia page in this sprint writes data.
- CMS form changes for the new catalog fields. Corrections go through a task this sprint.
- Licence assignment, the 9 missing format docs, the Mizan design system.
- Any change to the Quran content database.
- Changes to file storage, CMS permissions or old pages beyond the download route.
- Edge caching of anonymous HTML.
- Pushing a branch, opening a PR, deploying, or choosing the production download mode. These are human steps.
- Removing old views, Tailwind 3, Sprockets or esbuild.

## Dependencies on Earlier Sprints

- None. This is the repo's first sprint.
- Repo setup that lands on `qul-next` beside this sprint: a rule doc (`AGENTS.md`), `.agents/config.yaml` and a decision log. The first story records the gate commands in them; the docs write-back story brings them up to date.
- External: a local snapshot of both databases (setup in the private sprint notes); the public font and file CDN; Docker for the image build. No production credentials are available or needed for development (see spike S3).
- Parallel work: the unmerged `origin/qiraat/*` stack. This sprint keeps its edits to the files that stack touches small and expects to merge main into `qul-next`.

## Runtime Validation Plan

- **Production image.** Build the production Docker image locally from the sprint branch. Run it against clones of the snapshot databases with the Sidekiq service disabled and no SMTP variables. Evidence: the build log, a page response whose HTML contains server-rendered content, and the SSR service in the process list.
- **SSR failure.** Stop the SSR service in the running container. Evidence: the same URL returns 200, the page renders in the browser, and the failure is logged. Restart the service and SSR output returns.
- **Full browser run.** Run the whole Playwright suite on the local stack against real Rails on a snapshot clone: every page group, both download modes, phone and desktop widths, signed-in and anonymous.
- **Backfill replay.** Restore the data into fresh databases, run migrations and backfills, then run the backfills a second time. Evidence: the second run changes 0 rows, and a value edited by hand between runs is not overwritten.
- **Switch back.** Remove each page group from the setting. Evidence: the old ERB page is served at the same URL.
- **Truth on real data.** Counts on the home page, facet counts and popular order are checked against direct aggregate queries on the clone.
- Failure scenario the plan must answer: the image cannot boot in production mode without the master key. Fallback: boot with a dummy secret and pass what boot needs as environment variables. If boot still needs a real credential, the story stops and names the exact key as a human step.

## Integration Spikes

| Spike | Question It Answers | Pass Criteria | Fallback If Fails |
|-------|---------------------|---------------|--------------------|
| S1 Rails on the snapshot | Does the app boot, serve the old pages and run request specs against the snapshot and a clone, without destructive database tasks? | Old home, catalog and one detail page return 200; a request spec passes on a clone; `ar_internal_metadata` and `db/schema.rb` are as expected | Stop the sprint: nothing else can be proven |
| S2 Inertia beside the old pipeline | Do Vite, Inertia, React 19, Tailwind 4 and SSR (in development) run beside Sprockets, esbuild, Tailwind 3 and Turbo? Do generated types, typed routes and a drift check work? Do links, Devise sign-in and sign-out, CSRF and server-managed meta tags work across the old/new boundary? | One Inertia page renders with SSR in development; every old layout still loads its assets; each open question listed in story 001-02 has a recorded answer | Per item: full-page links both ways; hand-written prop types checked by request specs; plain form posts for sign-out |
| S3 Production image and SSR under Passenger | Does the image build with one precompile chain, and does a Node SSR service run beside Passenger with fallback? Can the image boot locally without the master key? | Image builds; SSR HTML is served; stopping the service gives client rendering; hashed Vite assets get long-cache headers | SSR off in production, pages client-rendered, server-managed meta tags still present; SSR moves to a follow-up |
| S4 Glyph-per-page rendering | Can a mushaf page of QPC V1, V2 and V4 Tajweed render from the page's word rows with one font per page from the CDN, fast enough without a new content-database index? What is the one correct font URL rule? | Pages 1, 2, 300 and 604 match the old site's preview for each of the three layouts; the page query time is recorded and acceptable | A page image where one exists; otherwise the unicode text of the page with a notice; V4 colour falls back to V2 glyphs |

## Sprint Exit Criteria

- With all three page groups on, every in-scope URL returns server-rendered HTML with correct meta tags. Evidence: the Playwright suite and request specs, quoted in `VALIDATION.md`.
- With all page groups off, every old URL behaves as on main. Evidence: the switch-back check in `VALIDATION.md` and a request spec per group.
- Every published resource has a detail page that returns 200 with a preview or an explicit "no preview" state, including the rows with known data errors. Evidence: a sweep spec over every published resource on the clone.
- The production image builds locally and serves SSR; stopping SSR degrades to client rendering. Evidence: `VALIDATION.md`.
- Migrations plus backfills replay on a fresh restore, and a second backfill run changes nothing. Evidence: `VALIDATION.md`.
- The download rules hold in both modes on both routes. Evidence: named request specs for unpublished, restricted, anonymous, signed-in and admin cases.
- The generated-types check, request specs, component tests and browser tests pass from one gate command. Evidence: gate output in the final handoff.
- The review report is generated and lists every drafted value. Evidence: its row counts against a direct query, recorded in `VALIDATION.md` as counts only.
- The sprint branch is merged into `qul-next` locally, nothing is pushed, and the handoff lists the human steps. Evidence: `git log` and the handoff note.
- `main` is unchanged, and no production data, generated report or private note is committed. Evidence: a check in the validation story.

## Risks / Assumptions To Validate

- **Long-lived branch.** The work lands on `qul-next`, which will drift from main. The qiraat stack will probably merge to main during or soon after the sprint and touches `downloadable_resource.rb`, `routes.rb`, `Gemfile`, `database.yml` and preview partials.
- **Data model change.** New columns on `downloadable_resources` and `downloadable_related_resources`, a new counter table, and a vocabulary (`script_family`) that sits near qiraat's `scripts` table. This needs the maintainers' agreement before cutover and is recorded in the decision log.
- **Drafted values can be wrong**, most of all "recommended" and which layout or font is the default per script family. They are drafted conservatively and shown as "not yet reviewed".
- **Licences: no rows exist.** Every Licence tab says "Licence not yet confirmed".
- **Download mode is a product decision.** Both modes are built; the production default is chosen at cutover.
- **SSR under Passenger is undocumented.** S3 proves it or turns it off.
- **Pre-1.0 dependency** (Typelizer) and a fast-moving one (Inertia v3). Versions are pinned.
- **Snapshot drift.** Editors change production while development runs on a snapshot from 2026-11-02.
- **The production runtime configuration is not in this repo.** Cutover needs it; this sprint lists what the new pages need.
- **No Ralph constitution yet.** The skill defaults for proof, testFirst and review cadence are used.
- More risks are in the private sprint notes.

## Ralph Notes

- Work on `sprint/001-inertia-foundation-and-catalog`, cut from `qul-next`. Never commit on or push to `main`. Never push or open a PR until a human says go.
- This repo is public. Never commit production data, generated reports, credentials or the private sprint notes. Handoffs, `lessons.md` entries and `VALIDATION.md` are public too: write them accordingly.
- Never run `db:test:prepare`, `db:schema:load`, `db:reset`, `db:drop` or `maintain_test_schema!` against the snapshot. Never start Sidekiq. Never set SMTP variables. The production image starts Sidekiq as a service by default: disable that service before the container starts.
- Fixtures come from public catalog and content rows only. Test accounts are fake and are made by a guarded development script.
- Do not reuse `Resources::SearchQuery` (in-memory, strips non-Latin characters) or either existing font URL builder.
- Do not touch `application.html.erb`, `app/javascript`, the esbuild config or the Tailwind 3 config. The Inertia installer and `vite install` both try to; revert what they inject.
- Use Inertia for page data: shared props, deferred and optional props, partial reloads and query-string visits. Do not build an API-and-client layer inside the app. The one exception is the spotlight, which needs its own JSON request because it runs on any page without changing that page's URL.
- Query objects and serializers must not depend on controllers, Inertia or the session, so the public API can reuse them next sprint.
- Links between new and old pages are plain full-page links in both directions.
- Human-only steps are planned on the last story: pushing `qul-next`, opening the PR, approving replies to the seven design comments, choosing the production download mode, and the items in the private sprint notes.
- Copy on every page: plain, short sentences (ASD-STE100 style), plain-label headings, then a `humanizer` pass. No slogans.
