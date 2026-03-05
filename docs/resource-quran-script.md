# Quran Script Guide

This guide is for resource users who want to download and integrate Quran Script datasets from QUL.

Category URL:

- [https://qul.tarteel.ai/resources/quran-script](https://qul.tarteel.ai/resources/quran-script)

## What This Resource Is

Quran Script resources provide Arabic Quran text in script-aware formats (word-by-word or ayah-by-ayah).

Depending on the selected package, entries can include:

- `verse_key` in `surah:ayah`
- Verse text (`text`)
- Rendering metadata (`script_type`, `font_family`)
- Word arrays (`words[].position`, `words[].text`, `words[].location`)
- Navigation metadata (`page_number`, `juz_number`, `hizb_number`)

## When to Use It

Use Quran Script data when building:

- Arabic Quran readers
- Word-by-word study views
- Integrations with translation, tafsir, and recitation by shared ayah keys

## How to Get Your First Example Resource

Use this stable selection rule:

1. Open [https://qul.tarteel.ai/resources/quran-script](https://qul.tarteel.ai/resources/quran-script).
2. Keep the default listing order.
3. Open the first published resource card.
4. Verify the detail page includes:
   - `Preview` tab
   - `Help` tab
5. Confirm available download links:
   - `sqlite`
   - `json`
6. Confirm whether package is `Word by word` or `Ayah by ayah`.

This keeps onboarding concrete without hardcoded resource IDs.

## What the Preview and Help Tabs Show

On the script detail page:

- `Preview` tab:
  - `Jump to Ayah`
  - Previous/next ayah navigation
  - Rendered Arabic output (word blocks in word-by-word packages)
- `Help` tab:
  - Sample JSON
  - Field descriptions (`verse_key`, `text`, `script_type`, `font_family`, `words`)
  - Usage examples for CSS and JavaScript rendering

Integration implication:

- You should carry `font_family` into UI rendering rules.
- You should use `verse_key` and `words[].location` as canonical join keys.

## Download and Integration Checklist

1. Download script package (`json` or `sqlite`).
2. Normalize keys:
   - Ayah key: `surah:ayah`
   - Word key: `surah:ayah:word`
3. Index verse rows by `verse_key`.
4. If word data exists, sort words by `position` before rendering.
5. Render with RTL + script-aware font fallback.
6. Join with translation/tafsir/recitation by ayah key.
7. Validate full-surah rendering and random ayah checks.

Starter integration snippet (JavaScript):

```javascript
const buildVerseIndex = (rows) =>
  rows.reduce((index, row) => {
    index[row.verse_key] = {
      text: row.text,
      scriptType: row.script_type,
      fontFamily: row.font_family,
      words: Array.isArray(row.words) ? row.words : []
    };
    return index;
  }, {});

const renderVerse = (container, verse) => {
  container.dir = "rtl";
  container.style.textAlign = "right";
  container.style.fontFamily = `${verse.fontFamily || "serif"}, "Amiri Quran", "Noto Naskh Arabic", serif`;
  container.textContent = verse.text;
};

const renderWords = (container, words) => {
  container.innerHTML = "";
  words
    .slice()
    .sort((a, b) => a.position - b.position)
    .forEach((word) => {
      const chip = document.createElement("span");
      chip.textContent = word.text;
      chip.title = word.location;
      chip.style.margin = "4px";
      chip.style.padding = "6px 10px";
      chip.style.border = "1px solid #e2e8f0";
      chip.style.borderRadius = "8px";
      container.appendChild(chip);
    });
};
```

## Real-World Usage Example

Goal:

- Render one selected ayah as full text plus word-by-word blocks.

Flow:

1. User selects ayah key.
2. App loads script row by `verse_key`.
3. App renders full verse text.
4. App renders `words[]` sorted by `position`.

Expected outcome:

- Arabic text is correct and readable.
- Word order is stable.
- Keys remain compatible with downstream joins.

## Common Mistakes

- Ignoring `font_family` and assuming script text itself is wrong.
- Joining with other datasets by row position instead of ayah key.
- Ignoring `words[].position` in word-by-word rendering.
- Mixing word-by-word assumptions into ayah-by-ayah resources.

## When to Request Updates or Changes

Open an issue when you find:

- Missing or incorrect `verse_key` rows
- Broken json/sqlite links
- Incorrect word order or missing `words[].location`
- Inconsistent `script_type` / `font_family` metadata

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorials](tutorials.md)
- [Tutorial 5: Quran Script End-to-End](tutorial-quran-script-end-to-end.md)
- [Translations Guide](resource-translations.md)
- [Tafsirs Guide](resource-tafsirs.md)
- [Downloading and Using Data](downloading-data.md)
