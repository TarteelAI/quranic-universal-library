# Lessons - 002-content-pages-and-guided-setup

> High-signal knowledge for future work in this sprint. Story-local context belongs in `spec.json` `notes`, not here.
> Only add entries that would help future work avoid a problem or rediscovery — durable, non-obvious, and not already in `notes` / code / architecture decisions / docs.

## Planning Context

Sprint 001's `lessons.md` applies unchanged: the database safety rules, the public-repo rule, the build and deploy traps, the Inertia facts and the catalog data facts. Read it first. Facts below were checked on 2026-11-10 against `qul-next` at `457e80ad`.

- **Branch.** Cut `sprint/002-content-pages-and-guided-setup` from `qul-next` after the four sprint 001 fast-follow PRs are merged there (shell polish, header menus, search pop-up, catalog correctness). Several stories build on them.
- **Prototype.** `../qul-redesign/ds` is prototype v8. Its working tree is the reviewed state and another session may be editing it: read only. The header menu is named Contribute in both the prototype and the app.
- **Page groups.** Three new groups: `content` (docs, FAQ, credits, the tools overview, the changelog), `start` (the guided setup and kits) and `requests`. The app submission form belongs to `apps`; the bundle and the changes to sprint 001 pages belong to `catalog` and `home`. Every group needs specs for on and off, and a link from one group's page to another group's page must work with any combination.
- **Docs resolve three ways.** `CommunityController#docs` serves a key from a markdown page (`DocsPageService`, `config/docs.yml`), from a resource tag (`DownloadableResourceTag`), or from an ERB partial under `app/views/docs`. Old pages also fetch `/docs/:key` by XHR and get a fragment with no layout; that answer must not change whatever the groups.
- **Runnable examples.** Tutorials hold fenced blocks tagged `playground-js`. The old pages run them; whether the new pages do is the answer of 002-01.
- **Format docs.** The per-type format docs are 19 ERB partials under `app/views/resources/docs`, some with sub-folders. They are old views and stay untouched; 9 types have none.
- **Existing models this sprint reads.** `Faq.published`; `ChangeLog` (`published`, `latest`, belongs to a `resource_content` in the content database, resource link through `public_downloadable_resource`). Old routes: `/faq`, `/credits`, `/tools`, `/docs`, `/docs/:key`, `resources :change_logs`.
- **Writes.** These are the first public write paths. Every one needs a signed-in user, is enforced on the server, and enqueues nothing (ActiveJob uses Sidekiq outside test). Daily limits are counted from the user's own rows: 5 requests, 3 app submissions. The cache is `null_store` in test and development, so nothing may depend on it.
- **Gated form.** An anonymous visitor always sees the whole form, disabled, with a sign-in prompt. Never hide the form or redirect before showing it.
- **Private fields.** An app's contact, and the author and voters of a request, never reach a public serializer.
- **Attachments.** Models switch the storage service by environment (`Rails.env.development? ? :local : :qul_exports`). The production service cannot be proven locally.
- **Navigation prop.** `nav` is a once prop, so an open tab keeps the navigation it loaded. 002-09 changes that.
- **RuboCop.** The locked RuboCop crashes on load in the `qul-dev` container. 002-04 fixes it before the gate can lint.
- **Worktrees.** `.gitignore` has `/node_modules/`, which does not match a symlink named `node_modules`; a worktree that links it shows it as untracked. Do not commit it. A worktree also needs its own `RAILS_ENV=test vite build`, `vite build --ssr` and `app/assets/builds` before request specs pass.

---

## Gotchas & Patterns

_Append new entries at the END. Heading: `### <short topic> — <STORY_ID>`. Never edit or reorder existing entries._
