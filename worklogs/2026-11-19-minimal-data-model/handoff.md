---
status: done
date: 2026-11-19
branch: refactor/minimal-data-model
base: qul-next
pr: 1079
---

# Minimal data model for qul-next

The maintainer's review: most of the schema additions on qul-next were not needed. An audit of the code
agreed for the catalog fields. qul-next now adds nothing to an existing catalog table.

## Shipped

- `baf554d0`, `6de1e018`: the three `apps` migrations are one `create_apps`. Resource requests and
  the anonymous download counter were removed, then restored unchanged: new tables are fine, the
  change to existing catalog data for values that can be derived is what goes.
- `4e48ca3e`: the columns `status`, `superseded_by_id`, `recommended`, `script_family`, `rendering`,
  `display_name`, `review` and `relation_type` are gone, with `Catalog::Review`, the Drafter and
  `catalog:mark_reviewed`. `Catalog::Derived` computes the values once per request from data
  production already has. `catalog:backfill` only fills empty slugs and deletes nothing.
- `c24eca0d`: the computed name is `catalog_name` on the model, so the CMS labels a resource with its
  plain `name` and does not load the catalog (review finding).
- Automated review fixes: the uniqueness check on related links runs on create only, so an existing
  repeated row still saves; a new slug ignores a `display-name` that is not text.

Schema against main: `apps`, `resource_requests`, `resource_request_votes`, their foreign keys and
`downloadable_files.anonymous_download_count`.

## Lessons

- A value a rule computes from existing data is not a column. Storing it needed a backfill, a review
  trail and a re-run for every new resource.
- Compare before deleting the old path: the old backfill and the new readers were run on two copies of
  the same data and compared per resource, with no difference. That check also caught two lines an unsafe
  RuboCop autocorrect broke.
- ActiveAdmin labels a record with `display_name` if the model has one. Don't give a model a computed
  method under that name.

## Decisions

- An editor overrides a computed value with a `meta_data` key: `display-name`, `script-family`,
  `rendering`, `status`, `superseded-by`, `recommended`. Invalid values are ignored. The maintainer has
  not approved these keys yet.
- The requires link follows the old backfill's rule, and shows where no link row exists.
- "Recommended" means the rule found the resource; the "suggested, not yet reviewed" form is gone.
- This replaces the stored catalog fields and review trail of sprint 001 and 002.

## Open

- Cost: a request that reads a catalog field loads the catalog (14 queries). Measured in development
  only: a warm type page is about 70 ms slower. Measure on staging; cache if needed.
- A display name is not frozen: a new resource with an existing name gives the old one a qualifier. The
  slug stays.
- Environments that ran the old migrations keep the removed columns; the code ignores them. Drop them
  by hand or rebuild the database.
- The browser specs passed, but not in one parallel run: timeouts on a single development server
  under load passed when re-run serially.
