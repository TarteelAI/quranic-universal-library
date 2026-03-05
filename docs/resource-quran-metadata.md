# Quran Metadata Guide

## What This Resource Is

Quran Metadata resources provide structural navigation entities such as juz, hizb, rub, manzil, and related Quran organization data.

Category URL: [https://qul.tarteel.ai/resources/quran-metadata](https://qul.tarteel.ai/resources/quran-metadata)

## When to Use It

- Building Quran navigation menus
- Filtering by juz/hizb/manzil
- Creating learning journeys based on Quran structure

## How to Download or Access It

1. Open the category URL above.
2. Select metadata package.
3. Download JSON or SQLite.
4. Validate structural keys and ayah references.

## Step-by-Step Integration

1. Import metadata tables/collections.
2. Map structural entries to ayah ranges.
3. Add indexed lookups by structure number (`juz`, `hizb`, etc.).
4. Connect metadata filters to your ayah list query.
5. Test navigation from structure -> ayah list -> ayah detail.

## Real-World Usage Example

Goal: add "Browse by Juz" in a mobile app.

Flow:

1. Load juz records from metadata.
2. User selects Juz 30.
3. App resolves ayah range for selected juz.
4. App renders ayahs and supports jump-to-next-juz.

Expected outcome:

- Users navigate Quran structurally without manual ayah lookup.

## When to Request Updates or Changes

Open an issue when:

- Structural ranges do not map correctly to ayahs
- Metadata entries are missing/incomplete
- Downloads are broken or out-of-date

Issue link: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)
