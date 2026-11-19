---
status: briefed
branch: docs/storage-stays-on-wasabi
base: qul-next
---

# Storage stays on Wasabi: make the code's wording true

## Task

On 2026-11-19 the team decided not to move object storage to Cloudflare R2. Production and
staging stay on the current S3-compatible provider. The storage code merged in #1072, #1073
and #1075 is driven by settings and works there unchanged, so it stays. Only the wording that
gives R2 as the reason, or says the move happened, is now false. Fix that wording. Change no
behaviour.

## Scope

1. `DECISIONS.md`, the entry "Object storage is on Cloudflare R2": replace it with a dated
   decision that storage stays on the current provider, that the settings-driven services, the
   public-host link, the 1-day signed links, `storage:verify` and `storage:fix_sizes` are kept,
   and that an R2 move was prepared and set aside. Follow the file's existing entry format.
2. `config/storage.yml` comments on `qul_exports` and on each `request_checksum_calculation`
   line, and the class comment in `lib/active_storage/service/r2_service.rb`: state the reason
   without tying it to one provider (a public file is linked on the public host, not on the
   storage endpoint; the SDK adds its own checksum only where S3 requires one, because some
   S3-compatible stores refuse two). Keep the class name `R2Service` and `service: R2`; say in
   the class comment that the name is historical. No rename.
3. `worklogs/2026-11-18-r2-storage/plan.md` and `handoff.md`: change the `status:` line to say
   the R2 move is superseded by `worklogs/2026-11-19-storage-stays-on-wasabi/`, and add one
   line under the title saying the same. Do not rewrite the rest.
4. `AGENTS.md`, `.env.sample`, `spec/lib/r2_service_spec.rb`: read them; change a line only if
   it states that storage is on R2 or will move there.
5. Write `worklogs/2026-11-19-storage-stays-on-wasabi/handoff.md` (frontmatter `status:` and
   `date: 2026-11-19`): what this PR changed, and one follow-up: "`amazon_s3` rows now resolve
   in the private bucket on the storage endpoint, not on AWS. Count those rows in production,
   and decide what to do with them, before production runs qul-next."

## Acceptance

- `git diff origin/qul-next --stat` touches only the files above; no non-comment line of
  `config/storage.yml` or any `.rb` file changes.
- `bundle exec rspec spec/lib/r2_service_spec.rb` passes (run only this spec; if the local
  environment cannot run it, say so in Concerns and do not claim it passed).
- `git grep -n -i 'r2' -- DECISIONS.md config/storage.yml lib/active_storage AGENTS.md .env.sample`
  shows no line that says storage is, or will be, on R2.

## Constraints

- This repository is public. No bucket names, hostnames (other than example.test), account
  ids, sizes or keys in code, docs, commits or the PR. Do not name the storage provider's
  buckets or the staging setup.
- Read `AGENTS.md` first and follow it. Short sentences, plain words.
- Work only in this worktree on branch `docs/storage-stays-on-wasabi`. Commit and push. Open a
  draft PR into `qul-next` titled "Storage stays on the current provider: wording" with a short
  body. End each commit message with the line
  `Claude-Session: https://claude.ai/code/session_015PLFa3tSBBq3GsKbD6uvJ8` and the PR body
  with `https://claude.ai/code/session_015PLFa3tSBBq3GsKbD6uvJ8`. Do not merge.

## Handoff contract

- **Checkpoint on commit.** Before every commit, append a line to this file (what the commit
  does, any decision it encodes) and stage this file in that same commit.
- **Status frontmatter:** `briefed` → `in-progress` → `done` | `blocked` | `partial`. Setting
  the final value is your last act.
- **Sections:** `## Done`, `## Decisions`, `## Concerns`, `## Not done / open`.
- **Blocked is a status, not a silence.** Write the blocker here and stop.
- **An approach note is not a stop.** Keep building unless it ends in a question only the
  orchestrator can answer.
