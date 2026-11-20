# Minimal data model for qul-next

The maintainer's review: most of the schema additions on qul-next are not needed. An audit of the code
agreed for the catalog fields. The rule: a whole new table is fine; what goes is every change to an existing
catalog table for a value that can be derived. This branch adds no column to `downloadable_resources` or
`downloadable_related_resources` and gets those values from data that production already has.

| Addition | Now |
|---|---|
| `downloadable_resources.script_family`, `rendering`, `status`, `recommended` | Computed when read by `Catalog::Inference`, with an optional override key in the existing `meta_data` |
| `downloadable_resources.superseded_by_id` | Computed when read (the "(Old)" name rule), override in `meta_data` |
| `downloadable_resources.display_name` | Computed when read (the rule the backfill used) |
| `downloadable_resources.review` + Drafter, review marks | Removed |
| `downloadable_related_resources.relation_type` | Computed: a link from a layout or glyph-page script to a font is "requires"; every other link pairs |
| `downloadable_files.anonymous_download_count` | Kept (scope change, 2026-11-19) |
| `resource_requests`, `resource_request_votes` | Kept (scope change, 2026-11-19) |
| `apps` (3 migrations) | Kept, as one migration |

Cutover: `db:migrate` (the `apps`, `resource_requests` and `resource_request_votes` tables and the counter
column), then fill empty `slug`s (an existing column) and import the apps. No deletes.

Order: `01-remove-extras`, then `02-derive-catalog`, on one branch and one PR into `qul-next`. `01` removed
requests and the counter; `02` restored both after the scope change and kept `01`'s single apps migration.
