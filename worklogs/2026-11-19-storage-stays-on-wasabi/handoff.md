---
status: done
date: 2026-11-19
branch: docs/storage-stays-on-wasabi
base: qul-next
pr: 1077
---

# Storage stays on the current provider

On 2026-11-19 the team chose not to move object storage to Cloudflare R2. The storage code from
#1072, #1073 and #1075 is driven by settings and works on the current provider unchanged, so it
stays. This PR changes wording only; no behaviour changes.

## Changed

- `DECISIONS.md`: the R2 entry is replaced by a dated decision that storage stays on the current
  provider, what code is kept, and that the R2 move was prepared and set aside.
- `config/storage.yml` and `lib/active_storage/service/r2_service.rb`: comments give the reasons
  without naming one provider. `R2Service` and `service: R2` keep their names; the class comment
  says the name is historical.
- `worklogs/2026-11-18-r2-storage/`: `plan.md` (the plan to move) is removed. `handoff.md` keeps
  only what is true on the current provider: the shipped code, the lessons and the open items.

## How storage works now

- One provider, chosen by the `QUL_STORAGE_*` settings. Public files (`qul_exports`, and what
  `UploadToCdn` writes) are in the public bucket; `database_backups` and `amazon_s3` are in the
  private bucket (`QUL_BACKUPS_BUCKET`) with signed links.
- Staging holds no storage key. It reads production's public files and cannot write, so a file
  that staging needs must be in the production bucket under the key the staging database
  records.
- `QUL_STORAGE_PUBLIC_HOST` is optional. Unset, public links start at `CDN_HOST`, else at the
  endpoint.

## Follow-up

- **App icons on staging.** `App#icon` uploads only in production, under a random key. Staging's
  icon rows need their files in the production bucket. A staging database copied from
  production again gets new icon rows from `apps:import` with no files, and that boot fails
  once. A lasting fix is a code change (fixed keys, or icons served from `public/app-icons`).

- `amazon_s3` rows now resolve in the private bucket on the storage endpoint, not on AWS. Count
  those rows in production, and decide what to do with them, before production runs qul-next.
