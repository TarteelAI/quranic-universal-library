---
agent: derive-catalog
status: done
---

## Task

Make the catalog fields computed values, not stored columns, so that qul-next adds no column to an
existing table. See `../plan.md`. `01-remove-extras` ran before you on this branch; read its file first.
Leeway on how; keep it the smallest design that works.

- Remove the two migrations on `downloadable_resources` and `downloadable_related_resources`
  (20261110100000, 20261110100100) and every read and write of their columns.
- `script_family`, `rendering`, `status`, superseded-by, `recommended`, the display name and the
  requires/pairs link type come from `Catalog::Inference` when a page is read, over the catalog the pages
  already load. The visible result must be the same as the backfill gives today for the same data.
- One override path: an editor can set a key in the existing `downloadable_resources.meta_data`
  (`script-family`, `rendering`, `status`, `recommended`, `superseded-by`, `display-name`) and it wins over
  the computed value. Validate override values when read; ignore invalid ones.
- Remove the review machinery: the `review` column, `Review`, `Drafter`, the drafting steps,
  `catalog:mark_reviewed`, the "not yet reviewed" markers in the frontend, and the drafted-values part of
  the review report. Keep the report's data-error checks if they still work without it.
- `catalog:backfill` shrinks to what still needs a stored value: empty `slug`s become NULL and get a slug
  (existing column; existing slugs never change). No deletes: where the old backfill deleted broken or
  duplicate links and taggings, the readers skip them. `short_summary` is computed when the column is empty.
- Load what the inference needs without N+1 queries on the catalog, type and resource pages.

## Acceptance

- `git diff origin/main -- db/schema.rb` shows one change: the new `apps` table (plus the schema version).
- `git grep` finds no use of the removed columns, the `review` jsonb or the Drafter.
- Specs cover the derivation through the pages' own interfaces (request or serializer level), including
  one override per key and an invalid override.
- A spec proves no N+1 on the catalog index and a type page, or the existing query-count checks pass.
- `bin/gate` passes. The catalog browser specs pass against real Rails.
- Generated frontend types are regenerated, with no drift.
- DECISIONS.md, GLOSSARY.md and the public docs match the new model. The PR body says what the schema
  change now is, what data the cutover writes, and how an editor overrides a value.
- The draft PR from `01-remove-extras` carries your commits and is green in CI.

## Constraints

- No new table, column, gem or config file. If something cannot be computed and needs storage, stop and
  write it under `## Not done / open` with the reason.
- Do not bring back anything `01-remove-extras` removed. Leave the `apps` feature alone.
- Slugs and existing URLs must not change for any resource that has a slug today.
- Never run `db:schema:load`, `db:reset`, `db:drop` or `db:test:prepare` against the production snapshot
  databases. Reading the local snapshot through the app, as AGENTS.md describes, is fine for checking
  results; no user data leaves the machine or enters a commit.
- The repo is public: no production data, credentials or infrastructure detail in commits or the PR.
- Never push to `qul-next` or `main`. Push only this branch.
- Keep the rake task names `catalog:backfill` and `apps:import` working: staging runs them at boot.

## Contract

- Set `status: done` before your first change.
- **Every commit**: before you make it, append a line to `## Commits` below (what the commit does
  and any decision it encodes) and stage this file in that same commit. No sha; the orchestrator
  resolves it from `git log`. Nothing about your work should exist only in your context.
- Your last act is flipping `status` to `done`, `blocked` or `partial` and filling the sections
  below. Blocked is a status you write down, never a silence.
- An approach note is not a stop: keep building after it unless it ends in a question only the
  orchestrator can answer.
- Repo rules apply unchanged: the repo's rule docs and the owning package's. Tests ship in the
  same commit as the code.
- Run no git state-changing command beyond committing your own work: no reset, rebase, force or
  branch switch. Other agents may be working the same tree.
- In a git worktree, run one plain command per shell call: no loops, `$(...)`, heredocs or shell
  variables next to `git` or the package manager. A hook refuses what it cannot verify. Write
  scripts with the Write tool. If the repo documents worktree setup, follow it before installing
  anything yourself.
- Do not wait with `sleep`. Run a long gate in the foreground with a long timeout, or in the
  background and wait for its notification. Do not hand back while your own work is running.
- Open your PR as a draft. The orchestrator marks it ready after a fresh review. Evidence (gate
  output, screenshots, live proof) goes on the PR, not in this file.
- Do not spawn a verifier or reviewer subagent of your own: its report cannot reach you. Run the
  check yourself, or write in `## Not done / open` that it is owed and the orchestrator runs it.
- Your final commit carries the terminal `status`; push it. Unpushed commits are not done.

## Commits

- Restore resource requests and the anonymous download counter as they are on `origin/qul-next` (scope
  change from the user, see Decisions). Every path `01-remove-extras` changed is back at its qul-next
  content except the apps migrations (still one `create_apps`), `.rubocop.yml` (the `find_by_slug_or_id!`
  allowance stays) and `db/schema.rb` (qul-next's, with the version of the last migration left,
  20261113200000). `01`'s RuboCop fixes in the restored files went with the restore: those files no longer
  differ from qul-next, so the gate does not check them. `plan.md` updated.
- Compute the catalog fields when read. The two migrations on `downloadable_resources` and
  `downloadable_related_resources` are gone, with every read and write of their columns. New
  `Catalog::Derived` loads the whole catalog once per request (14 queries, whatever the page shows) and
  applies `Catalog::Inference` and `Catalog::DisplayNames` (the old backfill step, now a pure function) in
  the order the backfill steps ran. `DownloadableResource` reads `display_name`, `script_family`,
  `rendering`, `status`, `superseded_by`, `recommended` and `summary` from it (`CatalogFields`), so the
  serializers and services keep calling the resource. Links and their type come from
  `Derived#links_from` / `#links_to`. Overrides are `meta_data` keys, validated when read. Review
  machinery removed (`review` column, `Catalog::Review`, `Drafter`, drafting steps, `mark_reviewed`,
  `ResourceReviewResource`, the frontend markers; `recommendation` prop is now `recommended: boolean`).
  `Catalog::Backfill` is one file: blank slugs to NULL, then a slug per resource without one. The review
  report keeps its data-error sections. `Catalog::SearchQuery` reads its resources from the request's
  catalog instead of loading them again. Decisions encoded: see Decisions.
- Handoff: status, the sections below, and the plan's link rule worded as the code does it.
- Review fix: the computed name is `DownloadableResource#catalog_name`, not `display_name`. ActiveAdmin
  labels a record with `display_name` first, so every CMS page naming a resource loaded the whole
  catalog; the CMS label is the plain `name` again, as on main. `display_name` stays the key inside
  `Catalog::Derived` and the `display-name` override. New CMS request spec: the model does not answer
  `display_name` and a CMS show page does not load the catalog.

## Done

- `git diff origin/main -- db/schema.rb`: the `apps`, `resource_requests` and `resource_request_votes`
  tables, their four foreign keys, `downloadable_files.anonymous_download_count` and the version
  (2026_11_13_200000). No change to `downloadable_resources` or `downloadable_related_resources`.
  Hand-edited, as `01` did; the clones' columns match it.
- Stored backfill against read-time values, on clones of the snapshot (the old backfill ran on a copy,
  `qul_cms_content_mdm_base`; the new code on `qul_cms_content_mdm`, with no catalog columns): 564
  resources, 0 differences in script family, rendering, status, superseded-by, recommended, display name,
  slug and summary; the 43 links and their types are the same list. Counts are in the PR body.
- Specs: `spec/serializers/catalog/resource_resource_spec.rb` (each computed field, one override per key,
  invalid overrides, skipped links), detail and type page request specs, the slug backfill spec. No N+1:
  the catalog index's query-count spec (bound now 15) and a new one on a type page (26 fonts against 2).
- Gate, split across the `qul-polish` container and the host as AGENTS.md says, on the `_mdm` clones:
  standalone tests 267 runs, RuboCop on 34 changed files, typelizer:check, typecheck, ESLint, Prettier,
  SSR build, RSpec 527 examples 0 failures, Vitest 450 passed.
- Browser: all 20 spec files, both widths, against development Rails with SSR (a Vite dev server for
  this worktree on its own port, forwarded into the container) on the `_mdm` clones. 248 tests: 203
  passed in the parallel run, 21 skip themselves (other width, public download mode, `LOOK_PATH`), 18
  failed and 6 did not run; those 24 pass when run one at a time (`--last-failed --workers=1`). The
  failures were 5 s and 30 s waits on one development server under parallel load, not assertions.
- Types regenerated, no drift. DECISIONS.md, GLOSSARY.md, AGENTS.md and the PR body updated.

## Decisions

- Scope change (user, through the orchestrator, 2026-11-19): resource requests and
  `downloadable_files.anonymous_download_count` stay. A whole new table is fine; what goes is the change to
  existing catalog tables for values that can be derived. The brief's "do not bring back anything
  01-remove-extras removed" no longer covers these two. Schema acceptance is now: `apps`,
  `resource_requests`, `resource_request_votes`, their foreign keys, the counter column and the version.
- The fields are read from the resource (`resource.status`), backed by one per-request catalog
  (`Catalog::Derived.current`, an `ActiveSupport::CurrentAttributes`). Passing the catalog through every
  serializer was the alternative; it touched about 12 call sites for no gain. A save of a resource or a
  link drops the loaded catalog.
- The requires-link follows the backfill's rule, not the plan's shorter wording: the one published font
  a layout's mushaf or a glyph script names, only when the resource links to no other font. The backfill
  also created the link where no row existed (10 of the 18), so the readers show those too
  (`Derived::Link` with no id). `alternative` and `supersedes` link types are gone (0 rows used them).
- Status and replacement: a `status` override wins; a `superseded-by` override alone makes the resource
  superseded; the inferred replacement shows only while the status is superseded. `superseded-by` takes a
  slug or an id.
- A `display-name` override is treated as the old stored display name was: used as it is, and never given
  to another resource.
- "Recommended" no longer has a "suggested, not yet reviewed" form: a resource the rule finds reads
  "Recommended". The rule finds none on the snapshot.
- The old ERB list (`resources/resource_view/_list`) still reads `short_summary` only, as on main.

## Concerns

- Cost: every request that reads a catalog field loads the catalog (564 rows, 14 queries, about 150 ms in
  development in the container). Warm page times against a server on qul-next code: catalog index and
  spotlight the same, a type page about 70 ms slower. Not cached, by the repo's rule that nothing needs
  the cache to be correct.
- A display name is no longer frozen: when an editor adds a resource with the name of an existing one,
  the existing one gains a qualifier. Its slug does not change.
- An invalid override is ignored without a message to the editor.
- `git grep relation_type` still finds the computed link type (`Derived::Link#relation_type`, the
  `relationType` prop). No code reads or writes the removed column.
- RuboCop's unsafe autocorrect broke two lines while I cleaned the touched files (`Hash#except` for a
  `reject`, `String#drop`). Both were caught (the comparison, the standalone tests) and fixed; a reviewer
  may want to look at `inference.rb`'s style-only changes.

## Not done / open

- CI on the PR: checked after the push; see the orchestrator report.
- Fresh-context review owed (orchestrator).
- Local databases left for re-checking: `qul_cms_content_mdm_base` (old backfill applied),
  `qul_cms_content_mdm` and the `_test_mdm` pair (this branch's migrations, slugs filled, fake accounts,
  apps imported, rows from the browser run). Drop them when done.
- The server on :3001 in `qul-polish` runs this worktree on the shared development clone, which still has
  the removed columns. The code ignores them.
