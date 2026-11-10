<!-- ralph-init template v1. This repo owns this file; edit it freely. `ralph-init` in update mode compares it with newer templates. -->
# Ralph Constitution: Quranic Universal Library (QUL)

This is the policy every Ralph skill applies in this repo: the planner (`create-sprint`,
`ralph-plan`), the builder, the reviewers (`ralph-polish`, `story-review`) and the orchestrator
(`ralph-loop`). Project-wide coding rules stay in the `rule_docs`; this file holds only what is
specific to building autonomously here. The loop mechanics (signals, handoff, state, checkpoint
steps) are the plugin's protocol. Don't restate them here.

## Repo stage

Live users. qul.tarteel.ai serves real visitors, and every push to `main` builds and deploys
(`.github/workflows/deploy.yml`). Changes stay backward compatible unless a sprint explicitly
scopes a migration, and every migration names its rollback. Existing URLs, redirects and meta
tags keep working until a sprint scopes their replacement.

## Quality gate

PR CI is the full gate. Locally, builders stay narrow:

```bash
ruby -Itest {files}               # standalone tests the story touches (no bundler, no database)
bundle exec rspec {files}         # specs the story touches, on the test clones
```

- CI (`.github/workflows/tests.yml`) loads every `test/**/*_test.rb` without bundler or a
  database. Nothing that boots Rails or touches a database may go under `test/`.
- `checkpoint_cmd` is `bin/gate`: the standalone tests, then RSpec on fresh test clones
  (`bin/snapshot-clones`). Specs `require 'clone_helper'`. Stories 001-02 and 001-05 extend
  `bin/gate` (generated-types drift check, `tsc`, ESLint and Prettier, Vitest; Playwright stays
  a separate command). `AGENTS.md` holds the local run recipe.
- Lint and format: `lint-staged` is configured in `package.json` (Prettier, ESLint, RuboCop,
  erblint), but no pre-commit hook is installed. Run the matching linter on the files you change.
- Long repo-wide runs can be offloaded with `rt run`. Don't run two repo-wide runs at once.

## Protected surfaces

Changes here never happen outside an explicit story scope. A diff that touches one triggers a
checkpoint review. A story that changes one is never `difficulty: low`. A builder that finds it
must change one out of scope signals BLOCKED.

- **Migrations and backfills**: `db/migrate/`, `db/schema.rb`, backfill tasks in `lib/tasks/`.
  Editors keep changing production data, so backfills must be idempotent and keyed on stable
  fields. The Quran content database is never changed by a migration.
- **Docker and deploy**: `Dockerfile`, `docker/` (service files, nginx config),
  `.github/workflows/deploy.yml`. A merge to `main` deploys to production.
- **Old pages and public URLs**: the ERB views, `ResourcesController`, `ResourcePresenter`,
  `application.html.erb`, `app/javascript`, `esbuild.config.js`, `config/tailwind.config.js`,
  and every existing URL, redirect and SEO tag (`SeoHelper`, `shared/_meta_tags.html.erb`).
  Live users and search engines depend on them.

## Escalation

On top of the protocol's BLOCKED classes, a builder stops for:

- Anything that needs a real secret: a production credential, the Rails master key, or
  production connection details. Name the exact key as a human step.

## Proof

How a criterion is proven, by surface:

| Surface | Proven by |
| --- | --- |
| Pure logic, exporters, services | named standalone tests under `test/`, or RSpec once it exists |
| Controllers, Inertia props, serializers | request specs on a clone of the snapshot databases |
| React components | component tests (Vitest) |
| UI pages | the `browser-verify` skill: Playwright against real Rails, with a story-scoped checklist |
| Data changes | migration plus backfill replayed on a fresh restore; a second run changes 0 rows |
| Production image | the image built locally and run against snapshot clones, with captured output |
| Sprint exit | the final validation story writes `VALIDATION.md` |

Builders may push branches and open pull requests. Human-only steps: merging to `main`, any
change to the production database, and production config and credentials.

## Planning defaults

- **testFirst:** true for pure logic, query objects, serializers, request specs and bug fixes;
  false for schema, UI, config, wiring and deployment.
- **difficulty:** high for production image and SSR work, data backfills over the live
  catalog, mushaf and font rendering, and anything that crosses the two databases.
- **Review cadence:** checkpoints after each spike, after migration or backfill clusters, at the
  boundary between foundation and pages, and on the final implementation story.

## Commits and PRs

- **Commit subject:** `[<story-id>] <plain imperative sentence>`, under 72 characters. Example:
  `[001-08] Add the resource catalog page`. One commit per story, holding the code, `spec.json`
  and any regenerated files together.
- **PRs:** plain `git` and `gh`, no stacking tool. Builders may push and open PRs as drafts
  against the branch the sprint was cut from (sprint 001: `qul-next`). Up to 150 files per PR.
  Never commit on or push to `main`. A human marks PRs ready and merges.

## Builder notes

- **This repo is public.** Never commit production data, anything from user, download, draft or
  admin tables, credentials, connection strings, generated review reports or private sprint
  notes. Handoffs, `lessons.md` and `VALIDATION.md` are public too. Don't describe weaknesses in
  the running site.
- **Two databases.** The CMS database (`ApplicationRecord`) and the Quran content database
  (`QuranApiRecord`) are separate Postgres databases. SQL can't join across them. New
  migrations use the CMS connection only.
- **Database safety.** Never run `db:test:prepare`, `db:schema:load`, `db:reset`, `db:drop` or
  anything that calls `maintain_test_schema!` against the snapshot. Tests run on clones made with
  `CREATE DATABASE … TEMPLATE …`. After `db:migrate`, commit only your own lines of
  `db/schema.rb`.
- **No side effects.** Never start Sidekiq and never set SMTP variables, locally or in a
  locally run production image.
- Use `localhost`, never `127.0.0.1` (`config/initializers/hosts.rb`).
- New pages are new files. Old code stays in place (see Protected surfaces).
- The Dockerfile installs no devDependencies: build tools are regular dependencies, and test and
  lint tools are devDependencies.

## Load-bearing code

`ralph-polish` never simplifies these without first proving them dead:

- The double `assets:precompile` in the `Dockerfile` (a known workaround).
- `find_by_slug_or_id!` and its `find` fallback (all-digit slugs are invalid because of it).
- Otherwise only what the rule_docs name.
