# Data Model

This page explains how resource users should model and join downloaded QUL datasets.

## Quran Hierarchy

Quran -> Surah -> Ayah -> Word

Common fields by level:

- Surah: surah number (`id` in the metadata `chapters` table), names, revelation place, ayah count
- Ayah: ayah key, surah and ayah numbers, text, juz/hizb/manzil context
- Word: word location, surah, ayah and word numbers, text, root/lemma/stem

## Core Shared Identifiers

- **Ayah key** `surah:ayah`, for example `"2:255"`. Most ayah-level JSON exports are objects keyed by it.
- **Word location** `surah:ayah:word`, for example `"1:1:2"`. Word-level JSON exports are keyed by it.
- **Word id** (`id` in the word-by-word Quran script): a global word index. Mushaf layouts point at it.

SQLite tables split the keys into columns, and the names vary by export:

| Export | Surah | Ayah | Word | Key column |
| --- | --- | --- | --- | --- |
| Quran script | `surah` | `ayah` | `word` | `verse_key` / `location` |
| Translation, transliteration | `sura` | `ayah` | | `ayah_key` |
| Word-by-word translation, transliteration, recitation | `surah_number` | `ayah_number` | `word_number` | |
| Ayah recitation, metadata ayahs | `surah_number` | `ayah_number` | | `verse_key` (metadata) |
| Tafsir | | | | `ayah_key` |
| Morphology (word) | | | | `word_location` |

## Recommended Join Patterns

- Translations, tafsir, topics: the ayah key
- Ayah themes: `surah_number` with the `ayah_from` to `ayah_to` range
- Morphology and word-by-word data: the word location
- Mushaf layouts: the word id (`first_word_id` to `last_word_id`)

## Practical Integration Notes

- Keep numeric identity fields as integers for stable joins.
- Normalize by resource type (script, translation, tafsir, morphology) instead of duplicating large text fields.
- Add indexes on common join keys before shipping production workloads.
- Validate key consistency on a sample batch before full import.
