---
agent: docs-fixes
status: briefed
---

## Task

Correct the public docs at `/docs` and the per-type format docs on resource pages. A review
compared them with the redesign prototype's rewritten docs and found the current docs are
complete and mostly right; port almost nothing. Fix only what is wrong or missing. The user asked
for the minimum necessary: no rewrites, no restructuring, no tutorial trimming.

1. **Wrong identifiers (highest value).** `getting-started.md`, `downloading-data.md`,
   `data-model.md` and `faq.md` (and any other file in `app/views/docs/markdown/` with the same
   error: `grep -n "data\[0\]\|surah_id\|ayah_number\|word_position"`; current hits include
   best-practices, contributing, download-resources, resource-guide-template) describe JSON as an
   array (`data[0]`) and columns as `surah_id` / `ayah_number` / `word_position`. Real exports:
   JSON objects keyed by `"1:1"` (ayah) and `"1:1:1"` (word); columns `surah` / `ayah` / `word`
   (some exports use `surah_number`, `sura`, `ayah_key`). **Verify every name you write against
   the exporters in `lib/exporter/*.rb`** (and their JSON writers) — do not take the prototype's
   word for anything. The prototype's identifier table and `data["1:1"]` snippet are a good
   starting text: `~/Dev/Tarteel/qul-redesign/ds/src/app/pages/docs.tsx` (and its data files under
   `ds/src/data`). Be careful: some `ayah_number`/`surah_number` uses may be correct for specific
   exports (e.g. ayah-by-ayah recitation JSON uses `surah_number`/`ayah_number`); change only what
   is wrong.

2. **Mushaf layout format doc.** `app/views/resources/docs/_mushaf_layout.html.erb` is a leftover
   database tag script ("Click on Run button"), not a format doc. Replace it with a format doc
   based on the prototype's mushaf-layouts page: the SQLite `pages`/`info` tables, `json/N.json`
   with type/alignment/data, docx — every field checked against
   `lib/exporter/export_mushaf_layout.rb` (or wherever it lives). Follow the style and structure
   of the other `_*.html.erb` format partials. Drop anything you can't confirm (e.g. an images
   folder, file sizes).

3. **Minimal gap fills.**
   - Add the missing file schema (fields and one small sample) to the recitation, font and
     surah-info format partials, from the exporters. Recitation: surah-by-surah and ayah-by-ayah
     shapes (ayah JSON keyed by `"1:1"` with `surah_number`/`ayah_number`/`duration`… — verify).
   - `app/views/resources/docs/morphology/_word_morphology*` is empty: fill it minimally from the
     exporter, or if there is no export for it, say so in Decisions and leave it.
   - FAQ licence answer: say each resource's licence is on its page, and that many still show
     "Licence not yet confirmed".
   - Links: docs use absolute `https://qul.tarteel.ai/...` links to the site itself, which send
     staging visitors to production. Make internal links relative (`/resources/...`). Leave links
     to other hosts alone.
   Nothing else: no new samples for other types, no tutorial changes beyond fixing identifier
   errors in them.

## Acceptance

- `grep` finds no wrong identifier forms left in `app/views/docs/markdown/` (list any deliberate
  remaining `surah_number`/`ayah_number` with the exporter that uses them, under Decisions).
- Each schema you document names its exporter file in your `## Done` notes, and you checked each
  field there.
- The docs and resource pages still render: run the existing docs/resource request specs and any
  docs parity spec (find them: `grep -rl "docs" spec | head`), via
  `docker exec qul-polish bundle exec rspec <files>`. Look at `/docs/getting-started` and one
  resource page's Docs tab on the local app if a server is running on http://localhost:3001
  (don't start a second one if the other agent has; ask nothing, just check `curl -s -o /dev/null
  -w '%{http_code}' http://localhost:3001/`).
- Prose follows house style: short, plain, high level first.

## Constraints

- Work in `/Users/hammadjutt/Dev/Tarteel/qul-polish-wt` on branch `polish/setup-and-docs` (already
  checked out). Another agent (setup and bundle) commits to the same branch in the same worktree,
  touching `app/services/`, `app/frontend/` and its own worklog file. Your files only:
  `app/views/docs/**`, `app/views/resources/docs/**`, specs that test them, and this file.
  **Commit with an explicit pathspec** (`git commit -m "..." -- <your files>`), never `-a` or a
  bare `git add .`. If `index.lock` exists, wait a few seconds and retry.
- Overrides to the contract below: don't open a PR and don't push. The orchestrator pushes and
  opens the one PR. Committed is done.
- Toolchain: host has no Ruby. Ruby runs in container `qul-polish` (`docker exec qul-polish ...`,
  mounts this worktree at /app). Git on the host only. Read `AGENTS.md` first (it has a docs
  section; `docs_root` is `app/views/docs/markdown`).
- Do not run `bin/snapshot-clones`, `db:*` tasks or full `bin/gate`. Runner queries read-only.
- The repo is public: nothing about production data counts, credentials or security.
- Don't port the prototype's API/MCP pages, its quran-script JSON, or its ayah-recitation JSON
  sample (known wrong). `api.md` stays as is.

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

## Done

## Decisions

## Concerns

## Not done / open
