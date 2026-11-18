---
agent: docs-fixes
status: done
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

- docs: fix join identifiers (JSON keyed by `"1:1"` / `"1:1:1"`, real SQLite column names per
  export) in the getting-started, downloading-data, data-model, FAQ, best-practices, contributing,
  download-resources and guide-template pages and two tutorials; FAQ licence answer; site links
  relative (`/resources/...`). README.md and api.md untouched.
- docs: format docs. Mushaf layout partial replaced (was the tag-description script) with a
  format doc; file schemas and samples added to recitation (ayah JSON corrected to the real keyed
  shape), font and surah-info partials. Resource pages spec now expects schemas for every type
  and a sample for surah-info.

## Done

- Identifiers: no `data[0]`, `surah_id` or `word_position` left in `app/views/docs/markdown`.
  Getting started, downloading data, data model (new column table per export), FAQ, best
  practices, contributing, download-resources, guide template; tutorials quran-metadata
  (`surah_id` -> `id`, the `chapters` column) and surah-information (`surah_id` -> `surah_number`).
  Checked against `lib/exporter/export_quran_word_script.rb`, `export_quran_ayah_script.rb`,
  `export_translation.rb`, `export_transliteration.rb`, `export_word_translation.rb`,
  `export_word_transliteration.rb`, `export_word_recitation.rb`, `export_ayah_recitation.rb`,
  `export_quran_meta_data.rb`, `export_tafsir.rb`, `export_ayah_theme.rb`, `export_topics.rb`,
  `export_quranic_morphology.rb`.
- `_mushaf_layout.html.erb`: from `lib/exporter/export_mushaf_layout.rb` and
  `downloadable_resources.rb#export_mushaf_layouts` (`pages`/`info` tables, `info.json` + `N.json`
  with type/alignment/first_word_id/last_word_id/data/surah_number, docx skipped for image
  layouts). Page 1 sample checked against the clone's first approved layout via the exporter's own
  methods (words 1-5 on line 2, surah_name line 1).
- `_recitation.html.erb`: `export_ayah_recitation.rb` (JSON keyed by `"1:1"`, `surah_number`,
  `ayah_number`, `audio_url`, `duration`, `segments`; table `verses`) and
  `export_surah_recitation.rb` (`surah.json`, `segments.json`, tables `surah_list`, `segments`,
  optional letter segments).
- `_font.html.erb`: `export_font.rb` + `#export_fonts` (one download per format, page fonts
  `p1`-`p604`, `ligatures.json`; ligature sample from the clone).
- `_surah_info.html.erb`: `export_surah_info.rb` (`surah_number`, `surah_name`, `text`,
  `short_text`; JSON keyed by surah number; CSV and `surah_infos` table). `surah_name` is
  `chapter.name_simple`, so transliterated in every language; `short_text` empty for some
  languages (checked on the clone).
- FAQ licence answer; 70 site links made relative across 37 markdown files.
- Specs green: `spec/requests/catalog/resource_pages_spec.rb`, `spec/requests/content/docs_spec.rb`,
  `spec/requests/content/docs_search_spec.rb` (53 examples, run with
  `VITE_RUBY_AUTO_BUILD=false`). Data tab parse checked with `Catalog::FormatDoc` on the clone:
  mushaf-layout gets pages/info/JSON schemas and the page JSON sample; recitation, font and
  surah-info now have schemas.

## Decisions

- Deliberate `surah_number`/`ayah_number` left in markdown: `tutorial-ayah-theme-end-to-end.md`
  (`export_ayah_theme.rb` uses `surah_number`), `tutorial-mushaf-layout-end-to-end.md`
  (`export_mushaf_layout.rb` uses `surah_number`), and the new column table in getting-started /
  data-model naming the exports that use them (metadata, recitations, word-by-word data).
- `morphology/_word_morphology.html.erb` left empty: `ExportQuranicMorphology#export_morphology`
  is `todo` (writes `pending.json`), so there is no export to document.
- `README.md` keeps absolute links: config/docs.yml does not serve it (GitHub-facing); `api.md`
  untouched per brief. The code comment in the mushaf tutorial playground now reads
  `/resources/mushaf-layout/12`.
- Markdown paragraphs written on one line: `DocsPageService` renders with `hard_wrap`, so wrapped
  lines become `<br>`.
- Mushaf "Download" and "Line type" tables use headers FormatDoc does not read as schemas, so the
  Data tab lists only real tables and fields.

## Concerns

- `tutorial-quran-metadata-end-to-end.md` playground uses juz rows with `from_surah`/`from_ayah`/
  `to_surah`/`to_ayah`; the juz export has `first_verse_key`/`last_verse_key`. Left: fixing it
  means rewriting the playground logic, beyond the brief.
- `_surah_info.html.erb` intro says some languages ship "a short summary and a longer article" as
  two versions; really every row has both `text` and `short_text`. Left as is, the new field list
  states it.
- Test env setup done on the host for the specs (gitignored, not committed): `RAILS_ENV=test
  vite build`, `vite build --ssr`, and the CSS builds copied from the main checkout's
  `app/assets/builds` (the container's tailwindcss gem has no aarch64-linux binary). The SSR
  bundle goes stale whenever the other agent edits `app/frontend`; rebuild before SSR specs.

## Not done / open

- Not looked at in a browser: no server on http://localhost:3001 (curl got no answer). Owed: a
  look at `/docs/getting-started`, `/docs/data-model` (the new table) and a mushaf layout's Docs
  and Data tabs.
