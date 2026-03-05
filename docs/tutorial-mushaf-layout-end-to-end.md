# Tutorial 2: Mushaf Layout End-to-End

This tutorial is for users who want to render page-accurate mushaf layouts from downloaded QUL data.

## 1) What This Resource Is

Mushaf Layout resources provide page-structured layout data for Quran pages.

In practice, this includes page lines and word ranges you can use to render page-faithful mushaf views.

Primary category:

- [https://qul.tarteel.ai/resources/mushaf-layout](https://qul.tarteel.ai/resources/mushaf-layout)

## 2) When to Use It

Use mushaf layout data when you are building:

- Page-by-page mushaf readers
- Navigation by page number (instead of only surah/ayah)
- Memorization or classroom tools that depend on printed page structure

## Why Mushaf Layout Is Different (and Helpful)

The Help sample code and preview on a detail page (for example [https://qul.tarteel.ai/resources/mushaf-layout/12](https://qul.tarteel.ai/resources/mushaf-layout/12)) show a key difference:

- `mushaf-layout` is a rendering-structure resource, not only a content resource.
- It tells your app *how* to render a page (`line_number`, `line_type`, `is_centered`, `first_word_id`, `last_word_id`).
- Most other resources (recitation, translation, tafsir, etc.) mostly give content keyed by ayah/word, but not page geometry.

Why this is useful:

- You can recreate a printed mushaf page layout more accurately.
- You can support page-first navigation and memorization workflows.
- You can combine layout + script + font consistently, instead of hardcoding line templates in app code.

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/mushaf-layout](https://qul.tarteel.ai/resources/mushaf-layout).
2. Keep the default listing order and open the first published card.
3. Confirm the resource detail page includes:
   - `Mushaf Page Preview` tab
   - `Help` tab
4. Confirm available download formats shown on the page (commonly `images`, `sqlite`, `docx`).

This keeps onboarding concrete without depending on a fixed resource ID.

## 4) What the Preview Shows (Website-Aligned)

On the mushaf layout detail page, preview helps you validate page rendering behavior before download:

- `Mushaf Page Preview` tab:
  - `Jump to page` selector
  - Previous/next page navigation
  - Rendered page output with line and word structure
- `Help` tab:
  - Required data to render a page (layout + script + font)
  - `pages` table schema (for line mapping)
  - `words` table schema expectations (for word ranges)
  - Sample rendering logic

Practical meaning:

- `pages` table controls line structure for each page.
- `first_word_id`/`last_word_id` ranges map into script words for line rendering.

## 5) Download and Use (Step-by-Step)

1. Download the selected mushaf layout package (for example `sqlite` and related assets).
2. Inspect layout records:
   - `page_number`
   - `line_number`
   - `line_type`
   - `is_centered`
   - `first_word_id`, `last_word_id`
   - `surah_number` (when relevant)
3. Load matching Quran script word data (word-by-word format).
4. For each page line:
   - If `line_type` is `surah_name`, render surah heading line.
   - If `line_type` is `ayah`, render words in `first_word_id..last_word_id`.
   - If `line_type` is `basmallah`, render basmallah line.
5. Apply alignment using `is_centered`.
6. Validate with at least three pages (start, middle, end) to catch mapping issues.

Starter integration snippet (JavaScript):

```javascript
// Select all lines for a single page and keep display order stable.
const linesForPage = (pagesTableRows, pageNumber) =>
  pagesTableRows
    .filter((row) => row.page_number === pageNumber)
    .sort((a, b) => a.line_number - b.line_number);

// Convert a word ID range into one display string.
const getWordsInRange = (wordsByIndex, firstWordId, lastWordId) => {
  const result = [];
  for (let id = firstWordId; id <= lastWordId; id += 1) {
    if (wordsByIndex[id]) result.push(wordsByIndex[id].text);
  }
  return result.join(" ");
};

// Render line text by line type rules.
const renderLineText = (line, wordsByIndex, surahNameByNumber) => {
  if (line.line_type === "surah_name") return surahNameByNumber[line.surah_number] || "";
  if (line.line_type === "basmallah") return "﷽";
  if (line.line_type === "ayah") return getWordsInRange(wordsByIndex, line.first_word_id, line.last_word_id);
  return "";
};
```

## 6) Real-World Example: Render One Mushaf Page

Goal:

- User opens page 1 and sees line-accurate mushaf rendering.

Inputs:

- Mushaf Layout package (line mapping)
- Quran Script package (word text)
- Surah names metadata

Processing:

1. User selects page number.
2. App loads all lines for that page from layout data.
3. App resolves words for each ayah line using word ID ranges.
4. App applies centered/justified alignment based on `is_centered`.
5. UI renders all lines in page order.

Expected output:

- Page structure matches expected mushaf layout.
- Surah name and ayah lines render in correct order (with basmallah lines when present in layout data).
- Page navigation remains stable across adjacent pages.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This playground follows the Help section sample pattern from:
// https://qul.tarteel.ai/resources/mushaf-layout/12

// Surah labels used by line_type = "surah_name".
const SurahNames = {
  1: "الفاتحة"
};

// Simulated rows from the layout DB "pages" table for page 1.
const pageData = [
  { line_number: 1, line_type: "surah_name", is_centered: true, first_word_id: null, last_word_id: null, surah_number: 1 },
  { line_number: 2, line_type: "ayah", is_centered: true, first_word_id: 1, last_word_id: 5, surah_number: null },
  { line_number: 3, line_type: "ayah", is_centered: true, first_word_id: 6, last_word_id: 10, surah_number: null },
  { line_number: 4, line_type: "ayah", is_centered: true, first_word_id: 11, last_word_id: 17, surah_number: null },
  { line_number: 5, line_type: "ayah", is_centered: true, first_word_id: 18, last_word_id: 23, surah_number: null },
  { line_number: 6, line_type: "ayah", is_centered: true, first_word_id: 24, last_word_id: 29, surah_number: null },
  { line_number: 7, line_type: "ayah", is_centered: true, first_word_id: 30, last_word_id: 33, surah_number: null },
  { line_number: 8, line_type: "ayah", is_centered: true, first_word_id: 34, last_word_id: 36, surah_number: null }
];

// Simulated rows from Quran script DB "words" table keyed by word id.
const wordData = {
  1: "بِسۡمِ", 2: "ٱللَّهِ", 3: "ٱلرَّحۡمَٰنِ", 4: "ٱلرَّحِيمِ", 5: "١",
  6: "ٱلۡحَمۡدُ", 7: "لِلَّهِ", 8: "رَبِّ", 9: "ٱلۡعَٰلَمِينَ", 10: "٢",
  11: "ٱلرَّحۡمَٰنِ", 12: "ٱلرَّحِيمِ", 13: "٣", 14: "مَٰلِكِ", 15: "يَوۡمِ",
  16: "ٱلدِّينِ", 17: "٤", 18: "إِيَّاكَ", 19: "نَعۡبُدُ", 20: "وَإِيَّاكَ",
  21: "نَسۡتَعِينُ", 22: "٥", 23: "ٱهۡدِنَا", 24: "ٱلصِّرَٰطَ", 25: "ٱلۡمُسۡتَقِيمَ",
  26: "٦", 27: "صِرَٰطَ", 28: "ٱلَّذِينَ", 29: "أَنۡعَمۡتَ", 30: "عَلَيۡهِمۡ",
  31: "غَيۡرِ", 32: "ٱلۡمَغۡضُوبِ", 33: "عَلَيۡهِمۡ", 34: "وَلَا", 35: "ٱلضَّآلِّينَ", 36: "٧"
};

// Read words between first_word_id..last_word_id (inclusive), sorted by id.
const getWords = (firstWordId, lastWordId) =>
  Object.entries(wordData)
    .map(([key, value]) => ({ id: Number(key), text: value }))
    .sort((a, b) => a.id - b.id)
    .filter((word) => word.id >= firstWordId && word.id <= lastWordId)
    .map((word) => word.text)
    .join(" ");

const getSurahName = (number) => `سورۃ ${SurahNames[number] || ""}`;

// Build sandbox preview container.
const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Mushaf Page Preview (Simulated)</h3>
  <p style="margin:0 0 12px;color:#475569;">Aligned with Help sample logic: page lines + word ID ranges</p>
  <div id="page" dir="rtl" style="border:1px solid #e2e8f0;border-radius:10px;padding:14px;background:#fff;font-size:1.1rem;line-height:1.85;"></div>
`;

const page = app.querySelector("#page");

const renderPage = () => {
  page.innerHTML = "";

  // Render in the same stable order as page line numbers.
  pageData
    .slice()
    .sort((a, b) => a.line_number - b.line_number)
    .forEach((line) => {
      const lineEl = document.createElement("div");
      lineEl.style.padding = "4px 0";
      lineEl.style.minHeight = "34px";
      lineEl.style.borderBottom = "1px dashed #f1f5f9";

      // Respect is_centered from layout metadata.
      if (line.is_centered) {
        lineEl.style.textAlign = "center";
        lineEl.style.display = "flex";
        lineEl.style.justifyContent = "center";
      } else {
        lineEl.style.textAlign = "justify";
      }

      // Choose content by line_type like the Help sample.
      switch (line.line_type) {
        case "surah_name":
          lineEl.textContent = getSurahName(line.surah_number);
          lineEl.style.fontWeight = "700";
          lineEl.style.fontSize = "1.25rem";
          break;
        case "ayah":
          lineEl.textContent = getWords(line.first_word_id, line.last_word_id);
          lineEl.style.fontWeight = "500";
          lineEl.style.fontSize = "1.1rem";
          break;
        case "basmallah":
          lineEl.textContent = "﷽";
          lineEl.style.fontWeight = "700";
          break;
        default:
          lineEl.textContent = "";
      }

      page.appendChild(lineEl);
    });
};

renderPage();
```

## 7) Common Mistakes to Avoid

- Joining layout lines to words with wrong word ID field.
- Ignoring `line_type` and rendering every line as ayah text.
- Ignoring `is_centered`, which changes page appearance.
- Validating only page 1 and skipping middle/end page checks.
- Mixing incompatible script/font with selected layout package.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Incorrect line-to-word mapping on a page
- Missing lines or broken page navigation
- Download package inconsistencies (`images`, `sqlite`, `docx`, metadata)
- Layout metadata that conflicts with preview behavior

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Mushaf Layouts Guide](resource-mushaf-layouts.md)
- [Quran Script Guide](resource-quran-script.md)
- [Fonts Guide](resource-fonts.md)
- [Quran Metadata Guide](resource-quran-metadata.md)
