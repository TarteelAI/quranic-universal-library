# Similar Ayah Guide

This guide is for resource users who want to integrate ayah-level similarity rankings.

Category URL:

- [https://qul.tarteel.ai/resources/similar-ayah](https://qul.tarteel.ai/resources/similar-ayah)

## What This Resource Is

Similar Ayah resources map each ayah to other ayahs with similarity metrics.

Typical fields:

- `verse_key`
- `matched_ayah_key`
- `matched_words`
- `coverage`
- `similarity_score`

## When to Use It

Use similar-ayah data for:

- Compare ayah features
- Pattern discovery tools
- Memorization reinforcement

## How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/similar-ayah](https://qul.tarteel.ai/resources/similar-ayah).
2. Keep default listing order.
3. Open first published card.
4. Verify `Similar Ayah Preview` and `Help`.
5. Download `json`/`sqlite`.

## What the Preview and Help Tabs Show

- `Similar Ayah Preview`:
  - Similar ayah list for selected ayah
- `Help`:
  - Similarity field definitions

Integration implication:

- Sort and interpret by score/coverage, not only raw match count.

## Download and Integration Checklist

1. Import similarity rows.
2. Group rows by `verse_key`.
3. Sort by `similarity_score`.
4. Join with script text for display context.

## Real-World Usage Example

Goal:

- Show top 5 similar ayahs for selected ayah.

Expected outcome:

- Ranked matches with interpretable metrics.

## Common Mistakes

- Treating score as strict equivalence.
- Ignoring coverage and matched-word context.

## When to Request Updates or Changes

Open an issue when:

- score/coverage values appear invalid
- key mapping looks incorrect
- downloads are broken

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorial 13: Similar Ayah End-to-End](tutorial-similar-ayah-end-to-end.md)
- [Mutashabihat Guide](resource-mutashabihat.md)
