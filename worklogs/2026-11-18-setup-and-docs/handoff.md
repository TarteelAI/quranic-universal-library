---
status: done
date: 2026-11-18
pr: 1069
---

# Setup, bundle tray and docs polish

## Shipped

- Setup results: a script-narrowed need with nothing tagged says so ("No IndoPak resources of this kind are tagged yet") and links to all scripts. No fallback to other scripts.
- Setup steps: Back/Continue sticks to the bottom of the viewport; a step change scrolls the new heading into view.
- Bundle tray: on the setup results only, it lists the files in the answers' formats, with "Show all files".
- Docs: join identifiers match the exporters, there is a column table per export in data-model, mushaf layout format doc, recitation/font/surah-info schemas, FAQ licence answer, relative site links.

## Decisions

- Script filter stays strict. Empty layout/font/text needs on staging come from `catalog:backfill` never having run there, not from the code. After the backfill, only IndoPak Tajweed text is empty, because no IndoPak tajweed script exists.
- `morphology/_word_morphology` is left empty: the morphology export is still a placeholder.
- Docs markdown paragraphs go on one line: the renderer uses `hard_wrap`.
- `surah_number`/`ayah_number` remain only where an exporter uses them (ayah theme, mushaf layout, the column table).

## Open

- Human step: `bin/rails catalog:backfill` on staging now, and in production at cutover.
- Saheeh International has 4 SQLite variants with no per-file hint.
- The quran-metadata tutorial's juz code uses `from_surah`/`to_ayah`; the export has `first_verse_key`/`last_verse_key`.
- `_surah_info` intro still implies two versions per language; every row has `text` and `short_text`.

## Lessons

- Running the gate in this setup: the Ruby steps run in Docker with `VITE_RUBY_AUTO_BUILD=false` after `vite build --ssr` on the host. The standalone tests need `bundle exec ruby`. Git commands inside the container fail on a worktree, so list the changed files on the host.
