# Glossary

Terms used in the code, the specs and `AGENTS.md` for the new (Inertia) pages.

- **Page group**: a set of URLs that switch together between the old ERB pages and the new
  Inertia pages. The groups are `home`, `catalog` (`/resources` and below) and `apps`
  (`PageGroups` in `app/services/page_groups.rb`).
- **Page group setting**: one deploy-time setting, `QUL_PAGE_GROUPS`, that lists the page groups
  served by the new pages. A group that is not listed is served by the old views, which stay in
  the code.
- **Drafted value**: a field value written by a backfill through inference, not by a person.
- **Review column**: one column on the resource row that records which fields hold drafted
  values, when they were written and by which backfill.
- **Review report**: a generated file that lists every drafted value and the known data errors,
  for the data team. It is generated on demand (`bin/rails catalog:review_report`) and is not
  committed.
- **Download mode**: one setting, `QUL_DOWNLOAD_MODE`, with two values. `sign_in`: Rails asks
  for sign-in, then sends the file. `public`: no account is needed.
- **Display name**: a name that is unique inside a resource type, built from existing fields.
  The editor's `name` is never overwritten.
- **Script family**: `madani`, `indopak` or `other`. Named `script_family` because the unmerged
  qiraat work uses "script" for one riwayah in one encoding.
