# Ayah Topics Guide

This guide is for resource users who want to map topics/concepts to related ayahs.

Category URL:

- [https://qul.tarteel.ai/resources/ayah-topics](https://qul.tarteel.ai/resources/ayah-topics)

## What This Resource Is

Ayah Topics resources provide topic entities and topic-to-ayah mappings.

Typical data includes:

- Topic metadata (`topic_id`, name, category)
- Mapping records from topic to `ayah_key`
- Topic counts/searchable labels

## When to Use It

Use ayah-topics data for:

- Topic-first Quran exploration
- Educational thematic pathways
- Concept search interfaces

## How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/ayah-topics](https://qul.tarteel.ai/resources/ayah-topics).
2. Keep default listing order.
3. Open the first published resource card.
4. Verify topics pane and `Help` tab are present.
5. Download available format (commonly `sqlite`).

## What the Preview and Help Tabs Show

- Topics pane:
  - Topic list + search + topic links
- `Help` tab:
  - Topic source/context notes
  - Mapping usage guidance

Integration implication:

- Keep topic metadata and mapping rows as separate layers.

## Download and Integration Checklist

1. Import topic rows.
2. Import topic-to-ayah mappings.
3. Index by `topic_id` and `ayah_key`.
4. Build topic search + topic detail endpoints.
5. Join mapped ayah keys with script/translation for display.

## Real-World Usage Example

Goal:

- User selects a topic and sees related ayahs with text preview.

Expected outcome:

- Stable mapping between selected topic and listed ayahs.

## Common Mistakes

- Mixing topic IDs from different datasets without normalization.
- Assuming one topic maps to a single ayah.

## When to Request Updates or Changes

Open an issue when:

- Topic-to-ayah mapping appears wrong
- Topic labels/categories are inconsistent
- Download links are broken

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorial 10: Ayah Topics End-to-End](tutorial-ayah-topics-end-to-end.md)
- [Quran Script Guide](resource-quran-script.md)
- [Translations Guide](resource-translations.md)
