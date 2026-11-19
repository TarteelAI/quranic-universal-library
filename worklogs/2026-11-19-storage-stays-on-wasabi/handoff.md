---
status: done
date: 2026-11-19
branch: docs/storage-stays-on-wasabi
base: qul-next
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
- `worklogs/2026-11-18-r2-storage/`: `plan.md` and `handoff.md` are marked superseded by this
  worklog.

## Follow-up

- `amazon_s3` rows now resolve in the private bucket on the storage endpoint, not on AWS. Count
  those rows in production, and decide what to do with them, before production runs qul-next.
