---
status: done (its goal, a move to Cloudflare R2, was set aside: see worklogs/2026-11-19-storage-stays-on-wasabi/)
date: 2026-11-18
branch: feat/r2-storage
pr: 1072
sprint: null
---

# Storage code: settings-driven services

This work began as the code half of a move to Cloudflare R2. On 2026-11-19 the team chose to
keep storage on its current provider (`worklogs/2026-11-19-storage-stays-on-wasabi/`,
`DECISIONS.md`). The code below stays, because settings drive it and it works on the current
provider. Nothing here is a plan to move storage.

## Shipped

1. `8a233f9e` (#1072) `R2Service` (`service: R2`; the name is historical): public links start at
   `public_host` (`QUL_STORAGE_PUBLIC_HOST`, else `CDN_HOST`, else the endpoint as before).
   `amazon_s3` is a private service on the `QUL_STORAGE_*` keys and `QUL_BACKUPS_BUCKET`; the
   `AWS_*`, `ALLOW_PUBLIC_EXPORT` and `DB_BACK_BUCKET` settings are gone. Signed links last
   1 day. `bin/rails storage:verify[service …]` checks that each blob row on a configured
   service has its object, at the row's byte size (not its content); rows on a service no longer
   configured are listed, not failed.
2. `96dadbf7` (#1073) `request_checksum_calculation: when_required` on the three S3 services.
3. (#1075) `bin/rails storage:fix_sizes[service …]` sets `byte_size` and `checksum` from the
   stored file on rows that differ from it.

## Lessons

- The old `ActiveStorage.service_urls_expire_in = 2.weeks` never applied: the engine overwrites it
  after initialization from `config.active_storage`. Signed links had been lasting 5 minutes.
- aws-sdk-s3 adds a CRC32 to uploads by default, beside the Content-MD5 Rails sends. Some
  S3-compatible providers refuse an upload with both. Reads and HEADs are unaffected, so only a
  real upload shows it.
- A pull request that conflicts with its base runs no Actions workflow, with no message saying
  so. #1072 showed no checks until `qul-next` was merged in.
- `apps:import` skips an entry that already has a row, so it cannot repair an icon whose stored
  file is missing.

## Follow-ups / open

Current follow-ups are in `worklogs/2026-11-19-storage-stays-on-wasabi/handoff.md`. Still open
from this work, on any provider:

- **Signed backup links last 1 day**, up from an effective 5 minutes. Shorten
  `service_urls_expire_in` if that is too long.
- **Rows whose size differs from their file**: `bin/rails "storage:fix_sizes[qul_exports]"`
  sets the row from the file. Not run on production.
- Not done: backup pruning (retention undecided), blob rows on services that no longer exist,
  the unused upload job, the admin view typo.
