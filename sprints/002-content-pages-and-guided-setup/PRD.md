# Sprint PRD: 002-content-pages-and-guided-setup

## Purpose / Why Now

Sprint 001 built the new home page, catalog, type pages, detail page and apps directory. A review of the running app found two gaps. First, the Docs, Developers and Contribute menus and most footer links still open old pages, so a visitor leaves the new site after one click. Second, the built catalog pages are plainer than the approved prototype: cards have no previews, and several sections are thinner or absent. This sprint closes both, and builds the rest of the prototype that does not need the public API: the guided setup, kits, the bundle tray, requests and the changelog. After it, the new site can launch as a whole, and sprint 003 adds the API on top.

## Context

Paths that start with `../` are sibling folders on the team's machines and are never committed here.

- `sprints/001-inertia-foundation-and-catalog/`: PRD, handoffs, `lessons.md` and `VALIDATION.md`. Its terms, conventions and landmines apply unchanged. `AGENTS.md`, `DECISIONS.md` and `GLOSSARY.md` were brought up to date by its last stories.
- `../qul-redesign/ds/`: prototype v8. Designed pages this sprint ports: docs layout (`src/app/pages/docs.tsx`, `src/app/docs/ui.tsx`), tools overview (`pages/more.tsx`), guided setup and kit (`pages/wizard.tsx`), the bundle tray and request dialog (`components/qul/chrome.tsx`, `app/shell.tsx`), the app submission form (`pages/apps.tsx`).
- `../qul-redesign/brief.md`: one-line intent for the pages the prototype only stubs (kits index, requests list, changelog).
- `../qul-redesign/research/data-requirements.html`: recommends kits as a curated file, a guided setup that filters the catalog, and listing bundle downloads one by one before any zip.
- The prototype comparison (team artifact, not committed): every remaining difference between prototype v8 and the sprint 001 pages, with screenshots. The in-scope gaps below come from it. The small differences in the shell, menus and search pop-up were fixed on `qul-next` before this sprint (see Dependencies).
- `config/docs.yml` and `app/views/docs/markdown/` (46 files): the docs content of record. `app/views/resources/docs/` (19 partials): the per-type format docs that the old detail page showed and the new one dropped.
- Docs already behind the code: the prototype's docs pages are a rewrite of 15 pages and describe an API that does not exist. They are a layout reference only this sprint. The prototype's developers page is almost entirely API, MCP and API keys: it belongs to sprint 003.

## Terms

- **Content page**: a public page that only shows content: docs, FAQ, credits, the tools overview, the changelog.
- **Guided setup**: the five-step flow at `/start` (goal, platforms, features, script, languages). It ends on the catalog, filtered for the answers.
- **Kit**: a curated set of resources that work together for one kind of app, with a reason for each item.
- **Bundle**: the visitor's own list of resources to download, kept in the browser.
- **Request**: a signed-in user's ask for a resource QUL does not have, with a status set by editors and votes from other users.
- **App submission**: an app entry sent through the form on `/apps`. It is not published until an editor approves it.
- **Gated form**: a form that every visitor can see. For a visitor who is not signed in, its fields are disabled and it asks for sign-in; after sign-in the visitor returns to the open form.

## In-Scope Outcomes

Content pages (first)
- Every page in `config/docs.yml` renders in the new site at its existing URL, from the existing markdown, in the prototype's docs layout: side navigation, on-page contents, search over the docs, previous and next links, and a phone layout. The search pop-up lists docs pages as a result group. Tag pages under `/docs/:key` keep working.
- Docs content is corrected only where it is outdated or no longer true (old page names, old URLs, screenshots of old pages, steps that changed with the new site). The "API: coming soon" page stays as a short notice. Each correction is listed in the story handoff.
- Code blocks have a copy button. The runnable examples in the tutorials keep running (see spike S1).
- The Developers menu and footer column point at the new docs pages for project setup, contributing code and the API notice. No separate developers page is built.
- `/faq` and `/credits` are rebuilt on their existing data sources.
- `/tools` is rebuilt as the tools overview: grouped cards that link to the old tools. No per-user access state and no progress bars.
- A changelog page lists the published change log entries with paging, and each entry has a page. The old `/change_logs` URLs redirect to it, and the detail page's Changelog tab links to it.
- No link in the new header, menus or footer opens an old content page. Links to contributor tools, sign-in and the CMS still open old pages.

Sprint 001 pages brought up to the prototype
- Resource cards on the catalog and type pages show a preview fitted to the type (mushaf page thumbnail, audio control, a line in the font or script, an ayah with its translation), a type icon, the one-line summary, the status and the formats.
- The catalog groups results by category when no sort or search is active, and offers a grid and a compact list view.
- Type pages with many resources (translations: about 200) get search, a language filter and paging.
- The home page library section gets the tabbed showcase (recitation, mushaf layout, translation, morphology) on real data, and the open-source section gets the contributor tool cards. The category list becomes the prototype's wide rows, each with a one-line hint and a count.
- The detail page Data tab shows the file contents, the schema of each table or file and a code sample. A separate Docs tab, as in the prototype, shows the per-type format guide from the existing format docs; a type without a guide has no Docs tab. The translation and tafsir notices from the old page return.
- The download panel shows a copyable file URL, the version and the updated date.
- Type and detail headers get the type icon; type pages get the "request a resource" card.
- The shared navigation updates in an open browser tab when the page group setting changes.

Apps directory in the CMS
- Apps are rows in the CMS database, not a file in the repo. The entries in `config/apps.yml` and their icons are imported as published, by an idempotent task.
- `/apps` has a gated submission form, as in the prototype (name, link, platforms, resources used, contact, consent), with an icon upload.
- Submissions are unpublished. Editors approve, edit and remove apps in the CMS.
- The GitHub issue form for app submissions is removed.

Guided setup, kits and bundle
- `/start` is built from the prototype. The script step takes several scripts. Answers live in the URL, so a setup can be resumed and shared. It ends on the catalog filtered for the answers, with the "filtered for your app" banner, the needs checklist and a way to edit the answers.
- Kits are a curated file in the repo. A kits index and a kit page are built (the kit page from the prototype, the index from the kit card on the prototype's home page). A kit page lists each item with its reason and an alternative.
- The home page gains the goal cards and the "Start from a kit" row. The header gains the "Start building" menu, and the hero and closing banner buttons point at the guided setup.
- The bundle tray: any resource card, kit or detail page adds to it, the header shows the count, and the list survives a reload. The tray lists each file with its own download link and offers the list as copyable text. It builds no zip.

Requests
- Requests are rows in the CMS database. The request dialog from the prototype is a gated form, opened from the catalog, type pages, the empty search state and the Contribute menu.
- A public requests page lists requests with status and vote count, sorted by votes or date. A signed-in user can vote once per request and take the vote back.
- Editors set status and hide requests in the CMS. Links to the GitHub request form are replaced.
- A signed-in user can send at most 5 requests and 3 app submissions a day. The limit is counted from the user's own rows in the database, not from a cache.

Sprint 001 leftovers owned here
- Ruby linting runs in this repo again and the gate includes it for changed files.

## Explicit Non-Goals

- The public API, MCP server, API keys, `/resources.json`, `llms.txt` and the developers page proper. Sprint 003 builds them and then revises the docs to describe them.
- Rewriting docs content, adding the 9 missing format docs, or porting the prototype's rewritten docs pages.
- The "Lines on this page" list and the large ayah blocks on the prototype's detail Preview tab: the built preview already renders the real page. The footer language picker and the header star count.
- A zip of a bundle or kit, and any attribution file generated from licences (no licence rows exist).
- Email of any kind: no "email me when it ships", no notification to editors.
- Importing existing GitHub request issues.
- Account pages, a new sign-in page, the ayah explorer, i18n.
- Rebuilding contributor tools or tool help pages. Access state and progress on tool cards.
- Marking resources as recommended. That is the data team's review from sprint 001; "Which one should I pick?" and kit defaults show what the data holds.
- Changelog entries that are not tied to a resource.
- Any change to the Quran content database. Removing old views, Tailwind 3, Sprockets or esbuild.
- Merging to `main`, deploying, production database or config changes, and turning page groups on in production. These are human steps.

## Dependencies on Earlier Sprints

- Sprint 001 is merged into `qul-next` (draft PR against `main` open). This sprint is cut from `qul-next`. It does not depend on that PR merging.
- Four sprint 001 fast-follow PRs against `qul-next` are merged before this sprint's branch is cut: shell polish (footer, three-way theme switch), header menus (grouped Contribute menu), the search pop-up (open state, page and tool results, in-app visits), and catalog correctness (cards as in-app visits, the comparison table on phones, the format docs button on type pages, three code-scanning alerts). The header menu keeps the name "Contribute".
- Sprint 001's human steps stay open and affect what this sprint can show: the data review (recommended, status, default pairs) and licence rows.
- External: the local snapshot of both databases; Docker for the image; the public file CDN. No production credentials.
- Parallel work: the unmerged `origin/qiraat/*` stack touches `config/routes.rb`.

## Runtime Validation Plan

- **Production image.** Build the image from the sprint branch and run it on snapshot clones with Sidekiq disabled and no SMTP variables. Evidence: a docs page, the guided setup and the requests page return server-rendered HTML.
- **Full browser run.** The whole Playwright suite on the local stack, every page group on, phone and desktop, signed-in and anonymous. It includes a sweep that follows every header, menu and footer link and records which pages are old.
- **Docs parity.** For every key in `config/docs.yml`, the new page returns 200 and holds the same headings as the old page for that key.
- **Switch back.** With each new page group off, the old page answers at the same URL, including the docs requests old pages make without a layout.
- **Data replay.** On fresh clones: migrate, import the apps, import again. Evidence: the second import changes 0 rows and an app edited between runs is not overwritten.
- **Write paths.** For app submissions, requests and votes: anonymous attempts are refused by the server, a signed-in submit creates one unpublished row, a second vote by the same user changes nothing, and nothing is enqueued or mailed.
- Failure scenario the plan must answer: the icon upload cannot be stored locally because the storage service needs production credentials. Fallback: the form and the rule are proven with the local disk service, and the production storage check is a named human step.

## Integration Spikes

| Spike | Question It Answers | Pass Criteria | Fallback If Fails |
|-------|---------------------|---------------|--------------------|
| S1 Docs through Inertia | Can the existing markdown renderer feed the new docs layout with server rendering, a contents list and search, and can the tutorials' runnable examples run in a React page without loosening the page's script rules? | Three pages (a tutorial with a runnable example, a resource guide, a tag page) render with SSR and match the old headings; one example runs | Runnable examples become code blocks with a copy button and a note |
| S2 First write from an Inertia page | Do a gated form, server-side validation errors, the CSRF cookie and the return from Devise sign-in work together, with an upload? | An anonymous visitor sees the disabled form, signs in, returns to the open form, submits with an icon, sees errors for bad input, and one row exists | Upload moves to a plain form post outside Inertia; the rest is unchanged |
| S3 Cards with previews at catalog size | Can about 550 cards show previews without slowing the catalog or loading every mushaf font? | The catalog's first response and transfer size stay within an agreed margin of sprint 001's; previews load only when a card is on screen | Previews on type pages and the first screen only; other cards keep an icon and summary |

## Sprint Exit Criteria

- No link in the new header, menus or footer opens an old content page. Evidence: the link sweep in `VALIDATION.md`.
- Every docs key renders in the new layout with the old headings. Evidence: the parity spec.
- With every new page group off, every old URL behaves as on `qul-next` before the sprint. Evidence: a request spec per group and the switch-back check.
- Resource cards show a preview, summary, status and formats on the catalog and every type page. Evidence: browser specs and screenshots against the prototype in `VALIDATION.md`.
- The guided setup produces a shareable URL and a filtered catalog for each goal. Evidence: a browser spec per goal.
- The bundle survives a reload and lists a working download link per file in both download modes. Evidence: browser specs.
- The write rules hold for app submissions, requests and votes. Evidence: named request specs for anonymous, signed-in, duplicate and invalid cases.
- The apps import replays cleanly. Evidence: `VALIDATION.md`.
- The production image builds and serves the new pages with SSR. Evidence: `VALIDATION.md`.
- The gate passes, including Ruby linting, and code scanning reports no alert in sprint files. Evidence: gate output and the PR checks in the final handoff.
- The sprint branch is merged into `qul-next` with a draft PR against `main`, `main` is unchanged, and the handoff lists the human steps. Evidence: `git log`, the PR link and the handoff.

## Risks / Assumptions To Validate

- **Size.** This is larger than sprint 001. The order is fixed so the sprint can be cut after any block and still be shippable: content pages, sprint 001 gaps, apps in the CMS, guided setup and kits, bundle, requests.
- **New tables.** Apps, requests and votes are new tables in the CMS database with new CMS screens. This is a protected surface; each migration names its rollback, and the data model needs the maintainers' agreement before cutover.
- **Public write paths.** These are the first pages that accept input from the public. Sign-in plus a daily limit per user are the only spam controls.
- **Undesigned pages.** The kits index, requests list and changelog have no prototype design. They are composed from existing components and need a design look before cutover.
- **Kits and the guided setup depend on unreviewed data.** With nothing marked recommended, kit items are named by hand in the kit file and may point at resources the data team later replaces.
- **Docs corrections are a judgement.** "Outdated" is decided per page by the builder and listed for human review; nothing is deleted without a note.
- **Card previews cost.** See S3.
- **Icon storage** cannot be fully proven locally.
- **Qiraat merge.** New types need catalog taxonomy entries, kit and guided-setup rules.

## Ralph Notes

- Work on `sprint/002-content-pages-and-guided-setup`, cut from `qul-next`. Never commit on or push to `main`.
- Everything in sprint 001's Ralph Notes and `lessons.md` still applies: the database safety rules, no Sidekiq, no SMTP variables, the public-repo rule, old code stays in place, new pages are new files behind page groups, query objects and serializers stay free of controllers and the session.
- Three new page groups, so each set can be turned on and off alone: `content` (docs, FAQ, credits, the tools overview, the changelog), `start` (the guided setup and kits) and `requests`. The app submission form belongs to `apps`, and the bundle and the changes to sprint 001 pages to `catalog` and `home`. With a group off, the old page answers unchanged. Old pages fetch `/docs/:key` without a layout for their help dialogs: that must keep working whatever the groups.
- Docs content stays in the markdown files and `config/docs.yml`. Do not copy it into components. The prototype's docs pages are a layout reference, not a content source.
- Gated forms: an anonymous visitor always sees the whole form, disabled, with a sign-in prompt. Never hide the form or redirect before showing it. The server enforces the rule as well.
- Mutating Inertia requests are new here. Sprint 001 recorded how CSRF and redirects to old pages behave (`AGENTS.md`, Integration answers).
- No job is enqueued by any new write path: ActiveJob uses Sidekiq outside test.
- The bundle is browser state only. Its download links are the same per-file download route as everywhere else, so the download rules and counting need no change.
- Copy on every page: plain, short sentences, plain-label headings, then a `humanizer` pass.
- Human-only steps for the last story's handoff: design look at the three undesigned pages, review of the docs corrections, agreement on the new tables, production storage check for icons, turning the new page groups on.
