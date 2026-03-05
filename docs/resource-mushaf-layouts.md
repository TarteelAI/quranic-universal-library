# Mushaf Layouts Guide

This guide is for resource users who want to download and integrate Mushaf layout datasets from QUL.

Category URL:

- [https://qul.tarteel.ai/resources/mushaf-layout](https://qul.tarteel.ai/resources/mushaf-layout)

## What This Resource Is

Mushaf Layout resources provide page-structured data used to render Quran pages in a mushaf-like format.

You can expect:

- Page-by-page line layout
- Line type metadata (`ayah`, `surah_name`, `basmallah`)
- Word ID ranges per ayah line
- Alignment metadata (`is_centered`)

## When to Use It

Use mushaf layout data when building:

- Page-faithful Quran readers
- Page navigation flows (prev/next page, jump to page)
- Learning tools that depend on printed page structure

## How to Get Your First Example Resource

Use this repeatable selection rule:

1. Open [https://qul.tarteel.ai/resources/mushaf-layout](https://qul.tarteel.ai/resources/mushaf-layout).
2. Keep the default listing order.
3. Open the first published resource card.
4. Verify the detail page has:
   - `Mushaf Page Preview` tab
   - `Help` tab
5. Confirm available download formats shown on page (commonly `images`, `sqlite`, `docx`).

This keeps onboarding concrete without hardcoding a resource ID.

## What the Preview and Help Tabs Show

On the mushaf layout detail page:

- `Mushaf Page Preview` tab:
  - `Jump to page` selector
  - Previous/next page navigation
  - Rendered page output with line/word structure
- `Help` tab:
  - Required resources for rendering (layout + script + font + surah names)
  - `pages` table fields and meaning
  - `words` table field expectations
  - Sample rendering code

Integration implication:

- Use `pages` table as your rendering skeleton.
- Use `first_word_id`/`last_word_id` to map ayah lines to word text.

## Download and Integration Checklist

1. Download the selected package.
2. Inspect fields in the layout data:
   - `page_number`
   - `line_number`
   - `line_type`
   - `is_centered`
   - `first_word_id`, `last_word_id`
   - `surah_number`
3. Load compatible word-by-word Quran script data.
4. Build index maps:
   - `wordsByIndex[word_index] -> text`
   - `surahNameByNumber[surah_number] -> surah name`
5. Render each line by `line_type`:
   - `surah_name` => render surah heading
   - `basmallah` => render basmallah line
   - `ayah` => render words from `first_word_id..last_word_id`
6. Apply line alignment using `is_centered`.
7. Validate on multiple pages (start, middle, end).

Starter integration snippet (JavaScript):

```javascript
const linesForPage = (pagesRows, pageNumber) =>
  pagesRows
    .filter((row) => row.page_number === pageNumber)
    .sort((a, b) => a.line_number - b.line_number);

const wordsInRange = (wordsByIndex, firstWordId, lastWordId) => {
  const words = [];
  for (let id = firstWordId; id <= lastWordId; id += 1) {
    if (wordsByIndex[id]) words.push(wordsByIndex[id].text);
  }
  return words.join(" ");
};

const renderLine = (line, wordsByIndex, surahNameByNumber) => {
  if (line.line_type === "surah_name") return surahNameByNumber[line.surah_number] || "";
  if (line.line_type === "basmallah") return "﷽";
  if (line.line_type === "ayah") return wordsInRange(wordsByIndex, line.first_word_id, line.last_word_id);
  return "";
};
```

## Real-World Usage Example

Goal:

- Render one complete page in a mushaf-like reader.

Required resources:

- Mushaf Layout package
- Quran Script package (word-by-word)
- Surah names metadata

Flow:

1. User opens page 1.
2. App loads lines for page 1 from layout data.
3. For each ayah line, app resolves words by `first_word_id..last_word_id`.
4. UI renders lines in order with centered/justified alignment.
5. User moves to next page and flow repeats.

Expected outcome:

- Page structure is visually consistent with selected mushaf layout.
- Text ordering and line boundaries remain stable.

## Common Mistakes

- Treating all lines as ayah lines and ignoring `line_type`.
- Using wrong key for word range mapping.
- Ignoring `is_centered` and breaking page appearance.
- Testing only one page and missing edge cases.
- Mixing incompatible script/font with selected layout.

## When to Request Updates or Changes

Open an issue when you find:

- Incorrect line-to-word mapping
- Missing lines/pages or broken page navigation
- Download package inconsistencies
- Metadata conflicts between preview and downloaded data

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorials](tutorials.md)
- [Quran Script Guide](resource-quran-script.md)
- [Fonts Guide](resource-fonts.md)
- [Quran Metadata Guide](resource-quran-metadata.md)
- [Downloading and Using Data](downloading-data.md)
