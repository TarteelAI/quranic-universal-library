# Glossary

Terms used in the code, the specs and `AGENTS.md` for the new (Inertia) pages.

- **Page group**: a set of URLs that switch together between the old ERB pages and the new
  Inertia pages. The groups are `home`, `catalog` (`/resources` and below), `apps`,
  `content` (docs, FAQ, credits, the tools overview, the changelog), `start` (the guided setup
  and kits) and `requests` (resource requests) (`PageGroups` in
  `app/services/page_groups.rb`).
- **Page group setting**: one deploy-time setting, `QUL_PAGE_GROUPS`, that lists the page groups
  served by the new pages. A group that is not listed is served by the old views, which stay in
  the code.
- **Computed field**: a catalog field that no column holds: the display name, script family,
  rendering, status, replacement, recommended flag, the requires-link and the summary of a
  resource without one. It is computed from the catalog when a page is read (`Catalog::Derived`).
- **Override**: a key in a resource's `meta_data` that an editor sets to replace a computed field
  (`display-name`, `script-family`, `rendering`, `status`, `superseded-by`, `recommended`).
- **Review report**: a generated file that lists the known data errors, for the data team. It is
  generated on demand (`bin/rails catalog:review_report`) and is not committed.
- **Download mode**: one setting, `QUL_DOWNLOAD_MODE`, with two values. `sign_in`: Rails asks
  for sign-in, then sends the file. `public`: no account is needed.
- **Display name**: a name that is unique inside a resource type, computed from existing fields.
  The editor's `name` is never overwritten.
- **Script family**: `madani`, `indopak` or `other`. Named `script_family` because the unmerged
  qiraat work uses "script" for one riwayah in one encoding.
- **Content page**: a new page of the `content` group that shows content the old pages already
  had: a docs page, the docs index, FAQ, credits, the tools overview or the changelog.
- **Guided setup**: the `start` group's `/start`, a few questions (goal, platform, features,
  script, languages) kept in the query string, that end on a list of catalog results per need
  (`GuidedSetup`).
- **Kit**: a curated set of published resources for one use, listed in `config/kits.yml` and read
  through `Kits` (`/kits`, `/kits/:key`).
- **Bundle**: the visitor's list of resources to download, kept in the browser
  (`localStorage` key `qul-bundle`) and downloaded file by file. The server never stores it.
- **Request**: a signed-in user's request for a resource QUL does not have yet
  (`ResourceRequest`), listed on `/requests` and voted on, one vote per user. Editors set its
  status and can hide it.
- **App submission**: an `App` row a signed-in user sends from the form on `/apps`. It stays
  unpublished until an editor publishes it.
- **Gated form**: a form only a signed-in user can send (`GatedForm`). A visitor who is not
  signed in sees the whole form disabled, with a sign-in link that returns to the open form.
