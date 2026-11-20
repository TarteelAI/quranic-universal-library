---
agent: derive-catalog
status: in-progress
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

- Set `status: in-progress` before your first change.
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

## Done

## Decisions

- Scope change (user, through the orchestrator, 2026-11-19): resource requests and
  `downloadable_files.anonymous_download_count` stay. A whole new table is fine; what goes is the change to
  existing catalog tables for values that can be derived. The brief's "do not bring back anything
  01-remove-extras removed" no longer covers these two. Schema acceptance is now: `apps`,
  `resource_requests`, `resource_request_votes`, their foreign keys, the counter column and the version.

## Concerns

## Not done / open
