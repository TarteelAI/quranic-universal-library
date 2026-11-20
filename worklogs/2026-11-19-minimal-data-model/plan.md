# Minimal data model for qul-next

The maintainer's review: most of the schema additions on qul-next are not needed. An audit of the code
agreed. This branch cuts the schema change to one new table (`apps`) and gets everything else from data
that production already has.

| Addition | Now |
|---|---|
| `downloadable_resources.script_family`, `rendering`, `status`, `recommended` | Computed when read by `Catalog::Inference`, with an optional override key in the existing `meta_data` |
| `downloadable_resources.superseded_by_id` | Computed when read (the "(Old)" name rule), override in `meta_data` |
| `downloadable_resources.display_name` | Computed when read (the rule the backfill used) |
| `downloadable_resources.review` + Drafter, review marks | Removed |
| `downloadable_related_resources.relation_type` | Computed: a link from a layout or glyph-page script to a font is "requires"; every other link pairs |
| `downloadable_files.anonymous_download_count` | Removed |
| `resource_requests`, `resource_request_votes` | Feature removed; requests go to the GitHub issue form |
| `apps` (3 migrations) | Kept, as one migration |

Data writes left at the cutover: fill empty `slug`s (an existing column) and import the apps. No deletes.

Order: `01-remove-extras`, then `02-derive-catalog`, on one branch and one PR into `qul-next`.
