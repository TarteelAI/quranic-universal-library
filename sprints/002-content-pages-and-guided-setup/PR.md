## Sprint 002: content pages, guided setup, kits and requests

Sprint 002 adds three page groups to the same switch and moves the apps directory into the
CMS. With a group unset, its URLs serve the old pages, as before. The draft PRs #1044, #1045,
#1046 and #1048 hold the same commits in four layers
(`sprints/002-content-pages-and-guided-setup/STACK.md`); the last two stories reach `qul-next`
through the sprint merge only.

### New page groups

| Group | Pages |
| --- | --- |
| `content` | Docs (`/docs/...`, side navigation, search), tag pages, `/faq`, `/credits`, `/tools`, `/changelog` (`/change_logs` redirects there) |
| `start` | Guided setup (`/start`: goals, features, languages, then a list of resources with one download bundle) and kits (`/kits`, `/kits/:slug`, from `config/kits.yml`) |
| `requests` | `/requests`: signed-in visitors ask for a resource and vote; editors handle requests in the CMS |

It also fills sprint 001 gaps: card previews for every type, grouped catalog landing and paging,
the "Which one should I pick?" block, a Docs tab with the type's format docs on resource pages,
and in-app links in the header, menus and footer. No new-page link opens an old content page;
contributor tools, sign-in and the CMS still open old pages.

### Settings

`QUL_PAGE_GROUPS` now takes `home`, `catalog`, `apps`, `content`, `start`, `requests`. Nothing
else is new. Submitted app icons use the existing ActiveStorage service (`qul_exports` in
production).

### Migrations and cutover order

1. `bin/rails db:migrate` runs three CMS migrations:
   - `20261112120000_create_apps`
   - `20261113120000_add_directory_fields_to_apps`
   - `20261113200000_create_resource_requests` (requests and votes)
2. `bin/rails catalog:backfill` (as in sprint 001; kits and setup read the slugs it fills).
3. `bin/rails apps:import` once, before `home` or `apps` serve traffic. It copies
   `config/apps.yml` into the `apps` table. Do not run it again after editors remove apps.
4. Turn on `content`, `start` and `requests` in `QUL_PAGE_GROUPS`.

The import was replayed twice on fresh clones of the production backups (second run: 0 rows,
no change). `sprints/002-content-pages-and-guided-setup/VALIDATION.md` has the production
image run, switch-back per group and the write-path checks.

### Data-model decisions that need the maintainers' agreement

`DECISIONS.md` (Sprint 002) has the reasons:

- An `apps` table (with icon, directory fields, a published flag) replaces `config/apps.yml` as
  the directory's source; submissions are unpublished rows, at most 3 per user a day.
- `resource_requests` and `resource_request_votes` tables; at most 5 requests per user a day,
  one vote per user. Deleting a user keeps their requests without an author and deletes their
  votes.

### Files shared with the qiraat stack

A trial merge of `origin/qiraat/p7-5-drop-legacy` into the sprint 002 head gives the same result
as sprint 001's table above: the same eight shared files, 30 conflicting files, 29 of which
also conflict when merging it into `main`; only `.gitignore` is new from these PRs. Keep the
later schema version (`2026_11_13_200000`).
