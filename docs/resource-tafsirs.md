# Tafsirs Guide

This guide is for resource users who want to download and integrate tafsir datasets from QUL.

Category URL:

- [https://qul.tarteel.ai/resources/tafsir](https://qul.tarteel.ai/resources/tafsir)

## What This Resource Is

Tafsir resources provide ayah-linked commentary. A tafsir entry can apply to one ayah or a group of ayahs.

Depending on the package, you may get:

- JSON grouped tafsir mapping by ayah key
- SQLite rows with group reference fields
- Tafsir text that may include simple HTML formatting

## When to Use It

Use tafsir data when building:

- Ayah detail views with commentary
- Study and reflection panels
- Comparative tafsir reading workflows

## How to Get Your First Example Resource

Use this stable selection rule:

1. Open [https://qul.tarteel.ai/resources/tafsir](https://qul.tarteel.ai/resources/tafsir).
2. Keep the default listing order.
3. Open the first published resource card.
4. Verify the detail page includes:
   - `Tafsir Preview` tab
   - `Help` tab
5. Confirm available downloads:
   - `json`
   - `sqlite`

This keeps onboarding concrete without hardcoding a resource ID.

## What the Preview and Help Tabs Show

On the tafsir detail page:

- `Tafsir Preview` tab:
  - `Jump to Ayah`
  - Previous/next ayah navigation
  - Arabic text + tafsir text
- `Help` tab:
  - JSON grouped export example
  - Explanation of object vs pointer values by ayah key
  - SQLite columns including `group_ayah_key`, `from_ayah`, `to_ayah`, `ayah_keys`

Integration implication:

- Tafsir can be shared across ayah ranges.
- Your resolver must follow grouped references.

## Download and Integration Checklist

1. Download the tafsir package (`json` or `sqlite`).
2. Normalize ayah keys to one format (`surah:ayah`).
3. Implement grouped tafsir resolution:
   - JSON object value = main tafsir text
   - JSON string value = pointer to main tafsir ayah key
4. For SQLite exports:
   - If `text` is empty, resolve via `group_ayah_key`
5. Join with Quran Script by ayah key.
6. Render tafsir as optional panel/expandable section.
7. Validate ayah-range/grouped entries with adjacent ayahs.

Starter integration snippet (JavaScript):

```javascript
const resolveTafsir = (tafsirByKey, ayahKey) => {
  const value = tafsirByKey[ayahKey];
  if (!value) return null;

  if (typeof value === "object" && value.text) {
    return {
      groupAyahKey: ayahKey,
      text: value.text,
      ayahKeys: Array.isArray(value.ayah_keys) ? value.ayah_keys : [ayahKey]
    };
  }

  if (typeof value === "string") {
    const main = tafsirByKey[value];
    if (main && typeof main === "object" && main.text) {
      return {
        groupAyahKey: value,
        text: main.text,
        ayahKeys: Array.isArray(main.ayah_keys) ? main.ayah_keys : [value]
      };
    }
  }

  return null;
};
```

## Real-World Usage Example

Goal:

- Show tafsir in an ayah detail panel, even when tafsir is grouped across multiple ayahs.

Flow:

1. User opens ayah key.
2. App looks up tafsir payload for that ayah key.
3. If record is grouped/pointer, app resolves main tafsir text.
4. App renders commentary and covered ayah range.

Expected outcome:

- No missing tafsir when the selected ayah belongs to a group.
- Commentary remains correctly mapped to its ayah coverage.

## Common Mistakes

- Treating every ayah key as standalone tafsir text.
- Ignoring pointer/group behavior in JSON exports.
- Ignoring `group_ayah_key` in SQLite rows.
- Rendering raw HTML tags without sanitization in production.

## When to Request Updates or Changes

Open an issue when you find:

- Broken grouped references or missing target keys
- Tafsir text mapped to wrong ayah range
- Downloaded files missing expected grouped fields
- Broken json/sqlite download links

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorials](tutorials.md)
- [Tutorial 4: Tafsir End-to-End](tutorial-tafsir-end-to-end.md)
- [Quran Script Guide](resource-quran-script.md)
- [Translations Guide](resource-translations.md)
- [Downloading and Using Data](downloading-data.md)
