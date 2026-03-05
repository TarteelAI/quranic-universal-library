# Morphology Guide

## What This Resource Is

Morphology resources provide word-level linguistic analysis such as roots, lemmas, grammatical tags, and related structures.

Category URL: [https://qul.tarteel.ai/resources/morphology](https://qul.tarteel.ai/resources/morphology)

## When to Use It

- Word study tools
- Arabic NLP research workflows
- Educational grammar features

## How to Download or Access It

1. Open the category URL above.
2. Select morphology package.
3. Download JSON or SQLite.
4. Validate word-level keys before import.

## Step-by-Step Integration

1. Import morphology rows with word-level keys.
2. Join with Quran Script by `surah_id + ayah_number + word_position`.
3. Store root/lemma/POS fields in normalized tables/collections.
4. Add indexes on ayah identity + word position.
5. Build per-word inspection UI in your app.

## Real-World Usage Example

Goal: create a "tap word for grammar details" feature.

Flow:

1. Render ayah words in order.
2. User taps a word token.
3. App queries morphology entry for matching ayah + position.
4. App displays root, lemma, and grammatical metadata.

Expected outcome:

- Users can inspect linguistic details word-by-word.

## When to Request Updates or Changes

Open an issue when:

- Word positions do not align with ayah text
- Root/lemma fields are missing or malformed
- Grammar tags are inconsistent across rows

Issue link: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)
