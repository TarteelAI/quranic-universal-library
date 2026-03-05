# Translations Guide

This guide is for resource users who want to download and integrate Quran translation datasets from QUL.

Category URL:

- [https://qul.tarteel.ai/resources/translation](https://qul.tarteel.ai/resources/translation)

## What This Resource Is

Translation resources provide translated text keyed by ayah, with multiple export structures.

Depending on the selected package, you may get:

- Simple translation text (`simple.json`, `simple.sqlite`)
- Translation with footnote tags
- Translation with inline footnotes
- Translation text chunks for structured rendering

## When to Use It

Use translation data when building:

- Multilingual Quran readers
- Arabic + translation learning experiences
- Search and discovery features in non-Arabic languages

## How to Get Your First Example Resource

Use this stable selection rule:

1. Open [https://qul.tarteel.ai/resources/translation](https://qul.tarteel.ai/resources/translation).
2. Keep the default listing order.
3. Open the first published resource card.
4. Verify the detail page has:
   - `Translation Preview` tab
   - `Help` tab
5. Confirm available download links (`simple.json`, `simple.sqlite`, and optional footnote/chunk variants).

This keeps onboarding concrete without hardcoding a resource ID.

## What the Preview and Help Tabs Show

On the translation detail page:

- `Translation Preview` tab:
  - `Jump to Ayah`
  - Previous/next ayah navigation
  - Arabic ayah display + translation display
- `Help` tab:
  - JSON/SQLite export overview
  - Simple export structures (nested array, key-value)
  - Footnote exports (tags, inline, chunks)

Integration implication:

- Simple format works for plain translation rendering.
- Footnote/chunk formats are better when annotation fidelity matters.

## Download and Integration Checklist

1. Download your selected translation package.
2. Identify the payload shape for each ayah:
   - String (simple translation)
   - Object (`t` + `f`) for tagged footnotes
   - Chunk array
3. Normalize ayah keys to one format (recommended: `surah:ayah`).
4. Load Quran Script rows for Arabic text from [Quran Script Guide](resource-quran-script.md).
5. Join Arabic + translation by ayah key.
6. Render translation with format-aware logic.
7. Validate on consecutive ayahs, not just one sample ayah.

Starter integration snippet (JavaScript):

```javascript
const toAyahKey = (row) => row.ayah_key || `${row.surah}:${row.ayah}`;

const buildTranslationIndex = (rows) =>
  rows.reduce((index, row) => {
    index[toAyahKey(row)] = row.translation;
    return index;
  }, {});

const normalizeTranslation = (payload) => {
  if (typeof payload === "string") return { text: payload, notes: [] };

  if (payload && typeof payload === "object" && payload.t) {
    const ids = [];
    const text = payload.t.replace(/<sup foot_note="([^"]+)">([^<]+)<\/sup>/g, (_, id, label) => {
      ids.push(id);
      return `[${label}]`;
    });
    return { text, notes: ids.map((id) => ({ id, text: payload.f?.[id] || "" })) };
  }

  if (Array.isArray(payload)) {
    const parts = [];
    payload.forEach((chunk) => {
      if (typeof chunk === "string") parts.push(chunk);
      else if (chunk?.type === "i") parts.push(chunk.text);
      else if (chunk?.type === "f") parts.push(`[${chunk.text}]`);
    });
    return { text: parts.join(""), notes: [] };
  }

  return { text: "", notes: [] };
};
```

## Real-World Usage Example

Goal:

- Display one ayah with Arabic text and translation, including footnotes when available.

Flow:

1. User selects an ayah key.
2. App loads Arabic text from Quran Script by that ayah key.
3. App loads translation payload by the same ayah key.
4. App normalizes translation payload and renders text + notes.

Expected outcome:

- Arabic and translation remain correctly paired.
- Footnotes appear for resources that include them.

## Common Mistakes

- Joining Arabic and translation by row index instead of ayah key.
- Assuming all translation resources have identical payload structures.
- Rendering tagged-footnote HTML directly without sanitization in production.
- Ignoring missing footnote entries or missing ayah keys.

## When to Request Updates or Changes

Open an issue when you find:

- Broken translation download links
- Translation text mapped to wrong ayah keys
- Footnote references without matching footnote text
- Missing language/source metadata

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorials](tutorials.md)
- [Tutorial 3: Translation End-to-End](tutorial-translation-end-to-end.md)
- [Downloading and Using Data](downloading-data.md)
- [Data Model](data-model.md)
