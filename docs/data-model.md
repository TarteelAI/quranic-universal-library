# Data Model

This page explains how resource users should model and join downloaded QUL datasets.

## Quran Hierarchy

Quran -> Surah -> Ayah -> Word

Common fields by level:

- Surah: `surah_id`, names, revelation type, ayah count
- Ayah: `surah_id`, `ayah_number`, text, juz/hizb/manzil context
- Word: `surah_id`, `ayah_number`, `word_position`, text, root/lemma/POS

## Core Shared Identifiers

- `surah_id` (or `surah`)
- `ayah_number` (or `ayah`)
- `word_position` (or `position`)

## Recommended Join Patterns

- Translations: `surah_id + ayah_number`
- Tafsir: `surah_id + ayah_number`
- Topics/themes: `surah_id + ayah_number`
- Morphology: `surah_id + ayah_number + word_position`

## Practical Integration Notes

- Keep numeric identity fields as integers for stable joins.
- Normalize by resource type (script, translation, tafsir, morphology) instead of duplicating large text fields.
- Add indexes on common join keys before shipping production workloads.
- Validate key consistency on a sample batch before full import.
