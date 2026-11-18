---
agent: setup-and-bundle
status: in-progress
---

## Task

Three fixes to the guided setup (`/start` and its results page) and the bundle tray, found by a
review of the flow on staging. Keep each change small: the user wants the flow kept simple, and
the review rejected adding new features (checklist ticks, a filter rail on results, "filter for my
app again", a last-step summary). Do not add those.

1. **Empty core needs.** On staging, for a reader goal with Madani or IndoPak, the needs Mushaf
   layout, Quran font and Quran text show 0 and "Nothing in the library fits this yet"; a
   research goal also gets Quran text 0. `GuidedSetup#items` (`app/services/guided_setup.rb`,
   around line 199) adds a `script` filter for these needs; the catalog filters on
   `script_family`, which `Catalog::Backfill`'s ScriptFamilies step fills. Likely staging never ran
   `bin/rails catalog:backfill`. The local development clone has 53 of 564 resources with
   `script_family` set.

   **Investigate first, then fix.** A proposed fix was "when the script filter returns 0, show the
   need without it". A concern was raised: that silently shows IndoPak users Madani layouts and
   fonts (wrong data for their app), and hides a missing data step in production. Determine:
   - Does the ScriptFamilies backfill cover these types (mushaf layout, font, Quran script/text)
     for both madani and indopak, so that with the backfill run every one of these needs is
     non-empty for both scripts? Check against the development clone (`docker exec qul-polish
     bin/rails runner ...`, read-only) and the backfill code.
   - Is any need legitimately empty for a script even after the backfill (no IndoPak resource of
     that type exists)?
   - Is the concern valid?
   Write the verdict and the chosen fix under `## Decisions` (commit it) before writing code. Pick
   the smallest fix that never shows the wrong script silently. Candidates, in rough order of
   preference: no code change beyond a clearer empty state if the data step alone fixes it; an
   honest empty state that links to the catalog or requests; a fallback only with a visible notice
   ("No IndoPak mushaf layouts are tagged yet; showing all scripts") — your call, justified.
   Include a spec for whatever behaviour you choose. Note in `## Not done / open` whether staging
   and production need `bin/rails catalog:backfill` run (the orchestrator puts that in the PR body
   as a human step; you cannot reach staging).

2. **Finish button buried on phones.** On the Languages step (and any long step) of `/start`,
   the Back/Continue (or "Show matching resources") bar sits ~2.7 screens below 94 language chips
   at 390px width. Make the step's navigation bar stick to the bottom of the viewport on phones
   (desktop too if it is harmless), without covering content (bottom padding). Also: after
   Continue, the next step opens scrolled past its title; scroll the step's heading into view on
   step change.

3. **Bundle tray ignores the chosen platform.** After picking iOS + Android (banner says "SQLite
   files"), the tray lists every file: Saheeh International shows 8 files (JSON and SQLite, three
   variants) with no hint which to take. When the setup answers imply formats, show the matching
   files first or only, with a way to see all files. Smallest version that makes the right file
   obvious; read `app/frontend/components/qul/bundle.tsx` and how setup answers reach the
   results page first. If the bundle can be filled outside the setup (catalog, kits), unchanged
   behaviour there.

## Acceptance

- Item 1: the verdict on the concern is written in `## Decisions`; on the development clone, a
  reader goal with Madani and with IndoPak shows non-empty Mushaf layout, Quran font and Quran
  text needs, or, where truly no data exists, an honest state that never presents another
  script's resources as matching. Spec covers it.
- Item 2: at 390px wide, the step navigation is visible without scrolling on every step, and the
  new step's heading is in view after Continue. Vitest or Playwright coverage where the repo has
  a pattern for it.
- Item 3: with iOS/Android answers, the tray makes the SQLite file the obvious pick; with no
  format answer, unchanged. Test covers it.
- Narrow checks green for touched files: `yarn -s typecheck`, ESLint/Prettier on changed files,
  `yarn vitest run <files>`, `docker exec qul-polish bundle exec rspec <files>`,
  `docker exec qul-polish bundle exec rubocop <files>`. If you change serializers/props,
  `docker exec qul-polish bin/rails typelizer:check`.
- A Playwright check or a screenshot of each of the three fixes on the local app (container
  `qul-polish` can serve on host port 3001: `docker exec -d qul-polish bin/rails server -b 0.0.0.0
  -p 3000`; build with `yarn build` on the host first). Note in `## Done` what you looked at.

## Constraints

- Work in `/Users/hammadjutt/Dev/Tarteel/qul-polish-wt` on branch `polish/setup-and-docs` (already
  checked out). Another agent (docs) commits to the same branch in the same worktree, touching only
  `app/views/docs/**`, `app/views/resources/docs/**` and its own worklog file. Do not touch those.
  **Commit with an explicit pathspec** (`git commit -m "..." -- <your files>`), never `-a` or a
  bare `git add .`, so you never sweep up the other agent's files. If `index.lock` exists, wait a
  few seconds and retry.
- Your files: `app/services/guided_setup.rb`, `app/frontend/pages/start/**`,
  `app/frontend/components/qul/bundle.tsx` and closely related setup/bundle components, their
  specs/tests, and this file.
- Toolchain: host has no Ruby. Ruby steps run in container `qul-polish` (`docker exec qul-polish
  ...`, mounts this worktree at /app). Node 24: prefix host yarn commands with
  `eval "$(fnm env)"; fnm use 24.19.0 >/dev/null;` or run `fnm exec --using 24.19.0 yarn ...`.
  Git runs on the host only. Read `AGENTS.md` (rules, gate, Inertia conventions) before coding.
- Do not run `bin/snapshot-clones`, `db:*` tasks, `catalog:backfill` or anything that writes the
  databases; do not run full `bin/gate` (the orchestrator runs it once at the end). Runner queries
  must be read-only.
- The repo is public: nothing about production data counts, credentials or security in commits.
- Overrides to the contract below: don't open a PR and don't push. Two agents share this branch,
  so the orchestrator pushes and opens the one PR. Committed is done.

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

- Item 1 decision recorded (no code): the script filter stays strict; the fix is an honest empty state, plus the backfill on staging/production.
- Item 1: setup results sections carry `scripts` (labels of the script filter); an empty script-narrowed section says no resources of that script are tagged yet and links to the type page (all scripts), never another script's resources as matches. Request spec + Vitest.

## Done

## Decisions

**Item 1, empty core needs: verdict.** The concern is valid; no silent fallback.

- `Catalog::Backfill::ScriptFamilies` drafts `script_family` for exactly the three types these
  needs filter on (`Inference::SCRIPT_TYPES` = quran-script, font, mushaf-layout), from the text
  encoding, then the font names, then a Madani/IndoPak tag. It skips nothing a person set.
- Development clone (backfill already applied: the stored value equals the inferred one for all
  68 published resources of those types), section totals of `/resources?goal=…&script=…`:
  reader madani layout 5, font 7, text 15; reader indopak layout 6, font 3, text 7. Every goal's
  layout, font and Quran text need is non-empty for both scripts; research gets text 15 / 7.
  So staging's zeros are the missing data step, not a code bug.
- The one need that stays empty after the backfill: **Tajweed text for IndoPak** (print goal, or
  the tajweed feature): 0, because no IndoPak tajweed script exists in the catalog (all three
  tajweed scripts are Madani). 15 of 26 published fonts also have no family (nothing to infer
  from), so they are left out of a script-narrowed font need; that is correct, not a gap.
- A fallback to "all scripts" would show Madani tajweed text and Madani fonts to IndoPak users as
  if they matched, and on staging would have hidden that the backfill never ran.

**Chosen fix:** keep the filter strict. When a script-narrowed need is empty, say so honestly:
"No IndoPak resources of this kind are tagged yet." with a link to the type's catalog page (every
script) labelled as such. The section gets a `scripts` prop (the script labels it was narrowed
to) so the page can word that; nothing else changes. Plus the human step: run
`bin/rails catalog:backfill` on staging and production.

## Concerns

## Not done / open
