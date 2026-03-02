# Data Model

QUL is split across two PostgreSQL databases.

## 1) `quran_dev`

Purpose: Quranic content and linguistic data.

Key characteristics:

- Main schema: `quran`
- Large content tables: verses, words, translations, tafsirs, scripts, audio metadata
- Also includes grammar/morphology entities

Representative tables:

- `quran.verses`
- `quran.words`
- `quran.translations`
- `quran.tafsirs`
- `quran.resource_contents`

## 2) `quran_community_tarteel`

Purpose: app/community and editorial workflow.

Representative tables:

- `users`
- `admin_users`
- `draft_translations`
- `draft_tafsirs`
- `resource_permissions`
- `versions` (change history)

## Why Two Databases?

- Separates canonical Quran content from community/editorial workflows.
- Makes operational boundaries clearer for backup, migration, and governance.
