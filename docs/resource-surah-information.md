# Surah Information Guide

## What This Resource Is

Surah Information resources provide chapter-level contextual data such as names, summaries, and descriptive metadata.

Category URL: [https://qul.tarteel.ai/resources/surah-info](https://qul.tarteel.ai/resources/surah-info)

## When to Use It

- Surah overview screens
- Intro cards before reading a chapter
- Study features that explain chapter context

## How to Download or Access It

1. Open the category URL above.
2. Select a surah-info package.
3. Download JSON or SQLite.
4. Validate chapter identity fields and language/source metadata.

## Step-by-Step Integration

1. Import surah-level metadata.
2. Join on chapter identity (`surah_id` / surah number).
3. Store localized titles/descriptions where available.
4. Cache chapter metadata for fast loading.
5. Render surah header cards in your reader app.

## Real-World Usage Example

Goal: show a surah introduction before ayah list.

Flow:

1. User opens Surah 36.
2. App fetches surah-info for that surah.
3. App displays chapter title and summary before ayahs.

Expected outcome:

- Users get context before reading.

## When to Request Updates or Changes

Open an issue when:

- Surah title or summary appears incorrect
- Language versions are missing or mismatched
- Surah identifiers are inconsistent

Issue link: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)
