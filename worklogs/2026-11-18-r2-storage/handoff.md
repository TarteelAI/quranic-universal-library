---
status: superseded (the R2 move is superseded by worklogs/2026-11-19-storage-stays-on-wasabi/)
date: 2026-11-18
branch: feat/r2-storage
pr: 1072
sprint: null
---

# Object storage on Cloudflare R2: the code half

The R2 move is superseded by `worklogs/2026-11-19-storage-stays-on-wasabi/`: storage stays on its current provider.

The app's three Active Storage services work on R2, and staging runs on its own R2 bucket.
Production still runs on its old provider; it switches with the qul-next launch. The operations
steps, with resource names and sizes, are in the team drop `qul-r2-runbook` (not for this public
repo). `plan.md` holds the decisions.

## Shipped

1. `8a233f9e` (#1072) `R2Service` (`service: R2`): public links start at `public_host`
   (`QUL_STORAGE_PUBLIC_HOST`, else `CDN_HOST`, else the endpoint as before). `amazon_s3` is a
   private service on the `QUL_STORAGE_*` keys and `QUL_BACKUPS_BUCKET`; the `AWS_*`,
   `ALLOW_PUBLIC_EXPORT` and `DB_BACK_BUCKET` settings are gone. Signed links last 1 day.
   `bin/rails storage:verify[service …]` checks that each blob row on a configured service has
   its object, at the row's byte size (not its content); rows on a service no longer configured
   are listed, not failed.
2. `96dadbf7` (#1073) `request_checksum_calculation: when_required` on the three S3 services.
   Without it R2 refuses every upload.
3. (#1075) `bin/rails storage:fix_sizes[service …]` sets `byte_size` and `checksum` from the
   stored file on rows that differ from it.

## Lessons

- The old `ActiveStorage.service_urls_expire_in = 2.weeks` never applied: the engine overwrites it
  after initialization from `config.active_storage`. Signed links had been lasting 5 minutes.
- aws-sdk-s3 adds a CRC32 to uploads by default. Beside the Content-MD5 Rails sends, R2 answers
  "You can only specify one non-default checksum at a time". Reads and HEADs are unaffected, so
  only a real upload shows it.
- A pull request that conflicts with its base runs no Actions workflow, with no message saying
  so. #1072 showed no checks until `qul-next` was merged in.
- `apps:import` skips an entry that already has a row, so it cannot repair an icon whose stored
  file is missing. On staging the icons were re-attached from `public/app-icons` per
  `import_key`.

## Follow-ups / open

- **Rows on the `amazon_s3` service are set aside** (owner's call, 2026-11-18): nothing is
  copied for that service. Come back to it: find their files or remove the rows. Detail is in the
  runbook drop.
- **Before production runs this code:** the host in `QUL_STORAGE_PUBLIC_HOST` or `CDN_HOST` must
  serve the exports bucket at its root.
- **Rows whose size differs from their file** (the file was replaced, the row was not):
  `bin/rails "storage:fix_sizes[qul_exports]"` sets the row from the file. Run on staging; run it
  on production at cutover, before `storage:verify`.
- **Zero-byte files were not copied** (the copy tool skips them): about 590 real files, mostly
  word images, that were already empty. They become 404 instead of an empty 200.
- **Signed backup links now last 1 day**, up from an effective 5 minutes. Shorten
  `service_urls_expire_in` if that is too long.
- The scheduled database backup is out of scope here; its open item is in the runbook drop.
- Carried from the plan, still not done: backup pruning (retention undecided), blob rows on
  services that no longer exist, the unused upload job, the admin view typo.
- Not checked on staging: a download through the site while signed in. The link it redirects to
  was built and fetched directly instead.

## Evidence

- #1072 and #1073: fresh-context review comments, checks, and the staging output in #1073's body.
- Staging on R2: `storage:verify[qul_exports]` 1,916 of 1,919 rows match, 0 missing; a 120 MB
  multipart upload and delete; an app created and deleted with its icon; the apps, credits and a
  font page load every image.
