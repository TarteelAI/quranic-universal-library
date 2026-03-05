# Transliteration Guide

## What This Resource Is

Transliteration resources represent Quran text using non-Arabic scripts/phonetic mappings to support pronunciation-oriented reading.

Category URL: [https://qul.tarteel.ai/resources/transliteration](https://qul.tarteel.ai/resources/transliteration)

## When to Use It

- Beginner-friendly reading modes
- Pronunciation assistance
- Transitional learning from transliteration to Arabic script

## How to Download or Access It

1. Open the category URL above.
2. Select transliteration package.
3. Download JSON or SQLite.
4. Validate ayah key compatibility with your script/translation tables.

## Step-by-Step Integration

1. Import transliteration rows by ayah identity.
2. Join with Quran Script and optional translation rows.
3. Add mode toggle: Arabic | Transliteration | Translation.
4. Ensure UI typography supports transliteration characters.
5. Validate that ayah ordering matches Quran Script.

## Real-World Usage Example

Goal: add transliteration toggle in ayah view.

Flow:

1. User opens ayah.
2. User turns on transliteration mode.
3. App renders transliteration text under Arabic line.

Expected outcome:

- Users can read pronunciation guidance alongside Quran text.

## When to Request Updates or Changes

Open an issue when:

- Transliteration text is misaligned with ayahs
- Character mappings appear broken
- Missing ayah transliteration entries are found

Issue link: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)
