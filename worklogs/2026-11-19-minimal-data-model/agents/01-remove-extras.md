---
agent: remove-extras
status: done
---

## Task

Remove three additions that the existing system already covers, so the schema change on qul-next
shrinks. See `../plan.md` for the whole picture. Leeway on how.

1. **Resource requests.** Remove the feature: the `resource_requests` and `resource_request_votes`
   migration, models, admin screen, controllers, routes, serializers, the /requests page and the request
   dialog, their specs and docs. Remove the `requests` page group. A `QUL_PAGE_GROUPS` value that still
   lists `requests` must not raise (staging has it set). Every "request a resource" entry point links to
   the GitHub issue form, as it already does when the group is off (`SiteNav::REQUEST_URL`).
2. **Anonymous download counter.** Remove `downloadable_files.anonymous_download_count`, its migration and
   the code that counts and sums it. Download totals read `download_count` only. Public download mode
   keeps working; it only stops counting.
3. **Apps migrations.** Squash the three `apps` migrations into one `create_apps` migration that keeps the
   first one's timestamp (20261112120000) and creates the final table. The data-moving SQL of the later
   migrations goes away: no environment that matters has rows in the old shape.

## Acceptance

- `git diff origin/main -- db/schema.rb` on the branch shows no `resource_requests`,
  `resource_request_votes` or `anonymous_download_count`. The `apps` table is unchanged from qul-next.
- `db/migrate` holds one apps migration and no requests or anonymous-counter migration.
- No dead references: no route, nav item, serializer, generated type or doc points at the removed feature.
- `bin/gate` passes. The affected browser specs pass or are removed with the feature.
- DECISIONS.md and the public docs match (edit or remove the entries on requests and the anonymous counter).
- A draft PR into `qul-next` is open, titled for the whole change ("Cut the data model to what is
  needed"), with a short body. The next agent adds to it.

## Constraints

- Do not touch the catalog fields (`status`, `script_family`, `rendering`, `recommended`,
  `display_name`, `review`, `superseded_by_id`, `relation_type`), `app/services/catalog` or the backfill.
  The next agent owns them.
- Produce `db/schema.rb` as AGENTS.md describes, from a database that has only this branch's migrations.
  Never run `db:schema:load`, `db:reset`, `db:drop` or `db:test:prepare` against the production snapshot
  databases.
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

- Remove resource requests, the anonymous download counter and two apps migrations. Requests: the
  table migration, models, CMS screen, controller, routes, serializers, `/requests` page, request
  dialog, generated types and routes, specs and docs; the `requests` page group is gone and every
  request link is the GitHub issue form again (RequestCard back in `components/qul/catalog.tsx`, as
  before 002-19). Counter: column, migration, `count_download`, `total_download_count`; totals read
  `download_count`; an anonymous download in public mode counts nothing. Apps: one `create_apps`
  (20261112120000) creates the final table, data-moving SQL dropped. `db/schema.rb` hand-edited to
  match a dump from fresh clones with only this branch's migrations. RuboCop fixes in the touched
  files (pre-existing offenses the gate sees once a file changes), and `find_by_slug_or_id!` added
  to `Rails/DynamicFindBy` AllowedMethods (a custom finder the autocorrect would break).

## Done

- All three removals; `git diff origin/main -- db/schema.rb` has no `resource_requests`,
  `resource_request_votes` or `anonymous_download_count`, and the `apps` table is unchanged.
- `PageGroups.enabled` already drops unknown names, so `QUL_PAGE_GROUPS=...,requests` does not
  raise; `spec/requests/site_shell_spec.rb` covers it.
- Gate steps run split as AGENTS.md says for Docker (host Ruby is 2.6): standalone tests, RuboCop
  on changed files, typelizer:check, typecheck, lint, format, SSR build, RSpec, Vitest: all pass.

## Decisions

- DECISIONS.md: "Anonymous downloads are a plain counter" rewritten as "Anonymous downloads are not
  counted"; the sign-in/daily-limit entry keeps app submissions only; "Three more page groups" is
  now two. GLOSSARY drops Request. The contributing doc points at the GitHub form.
- Specs and DB work ran on clones under branch-specific names (`*_mdm`), so the shared dev and
  test clones were not touched.

## Concerns

- None on the change itself.

## Not done / open

- Browser specs: ran catalog-search, shell and resource-page against the worktree's server on
  :3001. The changed tests passed (public-mode test skipped: server is in sign-in mode). 8 others
  failed because that server has no SSR (no Vite forward in the container) plus spotlight timing;
  not caused by this change, but a clean full run on a server with SSR is owed.
- Fresh-context review owed (orchestrator).
