---
status: code merged; operations in progress (see handoff.md)
date: 2026-11-18
branch: feat/r2-storage
base: qul-next
---

# Object storage on Cloudflare R2

The team approved moving all of this app's object storage to Cloudflare R2, with qul-next using
R2 only. This worklog covers the code change (#1072 and its follow-up #1073, into `qul-next`). The bucket setup, the data
copy, the staging switch and the production cutover are operations: their runbook, with resource
names, measured sizes and open decisions, is the team drop `qul-r2-runbook` on drop.tarteel.app
(read it with the drop tools; it is not for this public repo).

## Decisions already made

- **Service names stay.** `qul_exports`, `database_backups` and `amazon_s3` keep their names in
  `config/storage.yml`, so no `active_storage_blobs` row changes. Only where they point changes.
- **Two kinds of bucket.** R2 has no per-object public setting. Public files (`qul_exports`, and
  what `UploadToCdn` writes) go in a bucket served on a public host. `database_backups` and
  `amazon_s3` (the production default service) go in a private bucket.
- **Same settings, new values.** The app keeps reading `QUL_STORAGE_ACCESS_KEY`,
  `QUL_STORAGE_ACCESS_KEY_SECRET`, `QUL_STORAGE_BUCKET`, `QUL_STORAGE_ENDPOINT`,
  `QUL_STORAGE_REGION` and `QUL_BACKUPS_BUCKET`. One new setting, `QUL_STORAGE_PUBLIC_HOST`, is
  the base of public file links; unset, it falls back to `CDN_HOST`.
- **Public links use the public host.** Rails builds a public link from the storage endpoint. The
  R2 endpoint is never public, so a small service class builds the link from the public host.
- **Signed links last at most 7 days.** That is the SigV4 limit; the current 2 weeks is over it.
- **Downloads stay a redirect** to the file. No proxy mode.
- **Each deployment has its own bucket and key.** Staging never holds a production key.
- **Not in this PR:** backup pruning (retention is not decided), the unused upload job, the admin
  typo, blobs on services that no longer exist. They go in the handoff as follow-ups.

## Order of work

1. The code PR: done (#1072, #1073).
2. Operations, from the runbook, with the owner approving each step that creates a credential,
   writes a secret, starts a copy or changes DNS.
3. Staging runs on R2 (done). Production switches with the qul-next launch.

The PR is not a no-op on today's settings, so two things come before a deployment runs it:

- `amazon_s3` points at `QUL_BACKUPS_BUCKET`. Its existing files must be in that bucket first,
  or their rows return 404.
- Where `CDN_HOST` is set and `QUL_STORAGE_PUBLIC_HOST` is not, `qul_exports` links start at
  `CDN_HOST`. Confirm that host serves the exports bucket at its root.

Signed links last 1 day. The old 2-week setting never applied; the running value was 5 minutes.
