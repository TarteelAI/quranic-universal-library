# Mutashabihat Guide

This guide is for resource users who want to work with phrase-level Quran similarity mappings.

Category URL:

- [https://qul.tarteel.ai/resources/mutashabihat](https://qul.tarteel.ai/resources/mutashabihat)

## What This Resource Is

Mutashabihat resources map shared/similar phrases across ayahs.

Common files/structures include:

- `phrases.json`
- `phrase_verses.json`

## When to Use It

Use mutashabihat data for:

- Memorization revision tools
- Similar phrase comparison features

## How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/mutashabihat](https://qul.tarteel.ai/resources/mutashabihat).
2. Keep default listing order.
3. Open first published card.
4. Verify `Mutashabihat Preview` and `Help`.
5. Download available format (commonly `json`).

## What the Preview and Help Tabs Show

- `Mutashabihat Preview`:
  - Ayah-based phrase relationship exploration
- `Help`:
  - File structure and phrase-lookup flow

Integration implication:

- Resolve phrase IDs first, then fetch phrase objects.

## Download and Integration Checklist

1. Load phrase mapping file (`phrase_verses`).
2. Load phrase dictionary file (`phrases`).
3. For each ayah, resolve phrase IDs to phrase entries.
4. Optionally join with script words for highlighting.

## Real-World Usage Example

Goal:

- Show similar phrases for selected ayah in revision mode.

Expected outcome:

- Users can compare phrase overlaps across ayahs.

## Common Mistakes

- Treating phrase mapping as direct text data.
- Ignoring missing phrase IDs or orphan entries.

## When to Request Updates or Changes

Open an issue when:

- phrase IDs point to missing phrase entries
- phrase mapping appears incorrect
- download links are broken

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorial 12: Mutashabihat End-to-End](tutorial-mutashabihat-end-to-end.md)
- [Similar Ayah Guide](resource-similar-ayah.md)
