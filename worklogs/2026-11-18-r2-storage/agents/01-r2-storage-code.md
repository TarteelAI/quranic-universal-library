---
agent: r2-storage-code
status: done
---

## Task

Make the app's three ActiveStorage services work on Cloudflare R2, without changing what they do
on today's S3-compatible settings. Read `../plan.md` first: its decisions are fixed.

Today (`config/storage.yml`): `qul_exports` is a public S3 service on `QUL_STORAGE_*`;
`database_backups` is private on the same keys with `QUL_BACKUPS_BUCKET`; `amazon_s3` (the
production default, `config/environments/production.rb`) uses `AWS_*` in `us-east-2`.

What to build:

1. **Public links from a public host.** With `public: true`, `ActiveStorage::Service::S3Service`
   builds `blob.url` from the storage endpoint. On R2 that endpoint is the private S3 API host, so
   downloads (`catalog/downloads_controller.rb`, `resources_controller.rb`, which redirect to
   `file.file.url`) and the blob redirects for app icons and contributor logos would point at a
   host that refuses anonymous reads. Add a small service class (a subclass of `S3Service`,
   loadable as `service: R2` or similar from `lib/active_storage/service/`) that takes a
   `public_host` option and returns `<public_host>/<key>` for public links. With no `public_host`
   it behaves exactly as `S3Service`. Read the installed Rails 8.0 `s3_service.rb` before writing
   it; the public-link method and what it receives must be checked there, not assumed.
2. **`config/storage.yml`.** `qul_exports` uses the new service with
   `public_host: QUL_STORAGE_PUBLIC_HOST`, falling back to `CDN_HOST`. `amazon_s3` stops reading
   `AWS_*`: it becomes a private service on the `QUL_STORAGE_*` keys and endpoint with the
   `QUL_BACKUPS_BUCKET` bucket (same target as `database_backups`). Keep all three service names
   and the `'missing'` / `https://fix.me` fallbacks that let the app boot with nothing set. Keep
   the region default; R2 accepts `auto` and `us-east-1`.
3. **Signed link lifetime.** `config/initializers/active_storage.rb` sets 2 weeks, which is over
   the 7-day SigV4 limit, so signed links for private files cannot be made. Set it to 7 days or
   less (1 day unless you find a reason for longer; say which in Decisions).
4. **`storage:verify` rake task.** For every row in `active_storage_blobs`, check the object
   exists in the bucket its service points at and that its size matches `byte_size`. Print totals
   per service and the keys that are missing or differ, and exit non-zero when any are. Rows
   whose `service_name` is not configured are counted and listed, not an error. Read-only: HEAD
   requests only. It is what proves a copy is complete.
5. **Settings and docs.** `.env.sample`: add `QUL_STORAGE_PUBLIC_HOST` and `QUL_BACKUPS_BUCKET`
   with one line each. `Dockerfile`: remove the `AWS_ACCESS_KEY`, `AWS_ACCESS_KEY_SECRET`,
   `AWS_BUCKET`, `ALLOW_PUBLIC_EXPORT` and `DB_BACK_BUCKET` ARG/ENV pairs; add the two new
   settings beside the other `QUL_STORAGE_*`. `AGENTS.md` ("File URLs" note) and `DECISIONS.md`
   (one entry: storage on R2, public and private buckets, service names kept; Decision, Why,
   Cost). Keep docs to what a reader needs; this repo is public, so no bucket names, sizes or
   account details.

## Acceptance

- With `QUL_STORAGE_PUBLIC_HOST=https://files.example.test` and an R2-style endpoint set, a blob
  on `qul_exports` with key `qul-exports/a/b.zip` has the URL
  `https://files.example.test/qul-exports/a/b.zip`; a blob on `database_backups` has a signed URL
  on the endpoint host. Both are asserted in a test that makes no network call.
- With `QUL_STORAGE_PUBLIC_HOST` and `CDN_HOST` both unset, `qul_exports` URLs are what
  `S3Service` returns today (asserted).
- The app boots in production mode with no storage variable set (the image build and
  `assets:precompile` depend on this; `production.rb` already skips eager load for it).
- `bin/rails storage:verify` runs against a development clone and reports per-service counts;
  with no reachable storage it fails with a clear message, not a stack trace per row.
- `git grep -n "AWS_ACCESS_KEY\|AWS_BUCKET\|ALLOW_PUBLIC_EXPORT\|DB_BACK_BUCKET"` returns nothing
  outside `sprints/` and `worklogs/`.
- `bin/gate` passes (see `AGENTS.md` for how to run its Ruby and yarn halves), and the existing
  browser specs that assert the blob redirect are unchanged.
- Draft PR into `qul-next` with the gate output and the two URL shapes shown.

## Constraints

- In scope: `config/storage.yml`, `config/initializers/active_storage.rb`, the new service file
  and its test, `lib/tasks/` (one new file), `.env.sample`, `Dockerfile`, `AGENTS.md`,
  `DECISIONS.md`. A change outside this list needs a line in Decisions saying why.
- Do not change `lib/upload_to_cdn.rb` (it already takes the endpoint and bucket from the same
  settings and uses path-style addressing, which R2 accepts), the model `service:` choices, the
  download controllers, or any migration. Do not rename a service or touch blob rows.
- Do not add backup pruning, a storage gem, proxy mode or a checksum override. Whether R2 accepts
  the SDK's default upload checksums and multipart part sizes is tested on staging by the
  orchestrator; if it fails, the fix is a follow-up commit there.
- No real bucket name, endpoint, account id or key in code, tests, docs or the PR. Use
  `example.test` hosts.
- `test/` runs without bundler or a database; anything that needs ActiveStorage loaded goes under
  `spec/` and follows `spec/clone_helper.rb`.
- This is a worktree of a repo whose main checkout serves a shared dev server. Do not start,
  stop or migrate anything there.

## Contract

- Set `status: in-progress` before your first change.
- **Every commit**: before you make it, append a line to `## Commits` below (what the commit does
  and any decision it encodes) and stage this file in that same commit. No sha; the orchestrator
  resolves it from `git log`. Nothing about your work should exist only in your context.
- Your last act is flipping `status` to `done`, `blocked` or `partial` and filling the sections
  below. Blocked is a status you write down, never a silence.
- An approach note is not a stop: keep building after it unless it ends in a question only the
  orchestrator can answer.
- Repo rules apply unchanged: the repo's rule docs and the owning package's. Tests ship in the
  same commit as the code.
- Run no git state-changing command beyond committing your own work: no reset, rebase, force or
  branch switch. Other agents may be working the same tree.
- In a git worktree, run one plain command per shell call: no loops, `$(...)`, heredocs or shell
  variables next to `git` or the package manager. A hook refuses what it cannot verify. Write
  scripts with the Write tool. If the repo documents worktree setup, follow it before installing
  anything yourself.
- Do not wait with `sleep`. Run a long gate in the foreground with a long timeout, or in the
  background and wait for its notification. Do not hand back while your own work is running.
- Open your PR as a draft. The orchestrator marks it ready after a fresh review. Evidence (gate
  output, screenshots, live proof) goes on the PR, not in this file.
- Do not spawn a verifier or reviewer subagent of your own: its report cannot reach you. Run the
  check yourself, or write in `## Not done / open` that it is owed and the orchestrator runs it.
- Your final commit carries the terminal `status`; push it. Unpushed commits are not done.

## Commits

- feat(storage): R2-ready storage services. `R2Service` (public links on `public_host`),
  `config/storage.yml` (`qul_exports` on R2Service with `QUL_STORAGE_PUBLIC_HOST` or
  `CDN_HOST`; `amazon_s3` private on the `QUL_STORAGE_*` keys and `QUL_BACKUPS_BUCKET`),
  signed links 1 day (set so it takes effect), `storage:verify`, specs, settings and docs.
  Encodes the decisions below.

## Done

- `lib/active_storage/service/r2_service.rb`: `service: R2`, a subclass of `S3Service` that
  overrides only the private `public_url(key, **)` (checked in activestorage 8.0.5.1: `url`
  calls `public_url(key, **options)` when `public?`). With a `public_host` it returns
  `<host>/<key>`, each path segment escaped as `Aws::S3::Object#public_url` does; without one
  it calls `super`.
- `config/storage.yml`: as briefed; names, `missing` / `https://fix.me` fallbacks and the
  `us-east-1` region default kept.
- `config/initializers/active_storage.rb`: signed links 1 day, plus the Zeitwerk ignore for
  `lib/active_storage` (see Decisions).
- `lib/tasks/storage.rake`: `bin/rails storage:verify` (optionally `storage:verify[name,...]`).
  HEAD per row, per-service totals, lists missing, differing and unconfigured keys, exits 1 on
  any missing or differing; a service it cannot reach is one line, not one per row.
- Specs: `spec/lib/r2_service_spec.rb` (both URL shapes, the CDN_HOST fallback, the S3Service
  shape with neither host, the nothing-set fallbacks; no network) and
  `spec/tasks/storage_verify_spec.rb` (pass; missing, differing, unconfigured; unreachable).
- `.env.sample`, `Dockerfile` (old `AWS_*`, `ALLOW_PUBLIC_EXPORT`, `DB_BACK_BUCKET` removed;
  `QUL_STORAGE_PUBLIC_HOST`, `QUL_BACKUPS_BUCKET` added), `AGENTS.md` (File URLs),
  `DECISIONS.md` (one Storage entry).
- Observed: production boot with no storage variable, with eager load on and with
  `SECRET_KEY_BASE_DUMMY` (services build, `amazon_s3` bucket `missing`, expiry 1 day);
  `zeitwerk:check` clean; `storage:verify` on the development clone prints per-service lines
  and one "cannot read the storage" line per unreachable service, exit 1.

## Decisions

- **Expiry 1 day, set on `config.active_storage`.** The old
  `ActiveStorage.service_urls_expire_in = 2.weeks` never took effect: the engine overwrites it
  in `after_initialize` from `config.active_storage.service_urls_expire_in || 5.minutes`, so
  the running value has been 5 minutes (observed at runtime). 1 day as briefed; nothing found
  that needs longer.
- **Zeitwerk ignores `lib/active_storage`.** `lib` is an eager-load path and the Configurator
  `require`s the service by name; ignoring the folder keeps one loader for the file (no reload
  of a class the service registry holds). Lives in the in-scope initializer.
- **`storage:verify[names]` argument.** Lets the spec, and an operator after one copy, check
  one service without HEADs against every other; no argument checks all.
- **ACL kept.** `S3Service` adds `acl: public-read` for public services; R2 accepts that header
  since 2022-11 (R2 release notes), so nothing is overridden.
- **`amazon_s3` keeps its `upload: cache_control`**, so that service changes only where it
  points.
- Signed private URLs stay virtual-hosted (`<bucket>.<endpoint host>`), as today; no
  `force_path_style` added.

## Concerns

- **Not a no-op on today's settings, in two ways.** (1) `amazon_s3` moves from the `AWS_*`
  bucket to `QUL_BACKUPS_BUCKET` on deploy, so the existing `amazon_s3` rows 404 (and
  `storage:verify` reports them missing) until they are copied into the backups bucket.
  (2) Where `CDN_HOST` is set and `QUL_STORAGE_PUBLIC_HOST` is not, `qul_exports` links move
  from the endpoint to `CDN_HOST/<key>` on deploy; that is right only if `CDN_HOST` serves
  that bucket at its root (as `UploadToCdn` already assumes). The plan says the PR is
  mergeable before data moves; that holds only after (1) is copied and (2) is confirmed.
- Signed links go from an effective 5 minutes to 1 day, so a leaked backup link lives longer.
- The clones hold blob rows on services no longer configured; the task lists them as
  unconfigured (already a follow-up in the plan).

## Not done / open

- `assets:precompile` itself not run; the production boot with `SECRET_KEY_BASE_DUMMY` was.
- R2 itself not exercised (uploads, checksums, multipart, HEAD against a real bucket): owed on
  staging by the orchestrator.
- Browser specs not run (`spec/browser` untouched by this change).
- Fresh-context review owed (orchestrator).
