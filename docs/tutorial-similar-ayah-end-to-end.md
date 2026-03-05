# Tutorial 13: Similar Ayah End-to-End

This tutorial is for users who want to show ayah-to-ayah similarity results (matched words, coverage, and score).

## 1) What This Resource Is

Similar Ayah resources provide ayah-level similarity records.

Typical fields include:

- `verse_key`
- `matched_ayah_key`
- `matched_words_count`
- `coverage`
- `score`
- `match_words_range` (word position range in matched ayah)

Primary category:

- [https://qul.tarteel.ai/resources/similar-ayah](https://qul.tarteel.ai/resources/similar-ayah)

## 2) When to Use It

Use similar-ayah data when building:

- Compare-verses tools
- Pattern discovery across Quranic wording
- Memorization reinforcement features

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/similar-ayah](https://qul.tarteel.ai/resources/similar-ayah).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Similar Ayah Preview` tab
   - `Help` tab
4. Confirm available downloads (`json`, `sqlite`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On similar-ayah detail pages:

- `Similar Ayah Preview` tab:
  - `Jump to Ayah`
  - Source ayah card for selected ayah
  - "X has N similar ayahs" banner
  - List of matching ayahs for selected ayah
  - Highlighted matched words inside matched ayah text
  - Match summaries ("This ayah matches N words with X% coverage and a similarity score of Y")
- `Help` tab:
  - Field definitions (`verse_key`, `matched_ayah_key`, `matched_words_count`, `coverage`, `score`, `match_words_range`)
  - Export format notes

Practical meaning:

- Similarity is scored data, not binary “same/different”.
- You should sort by score/coverage and let users inspect why matches appear.

## 5) Download and Use (Step-by-Step)

1. Download selected package (`json` or `sqlite`).
2. Import similarity rows.
3. Group rows by `verse_key`.
4. Sort matches by score and/or coverage.
5. Join with script text for readable display.
6. Use `match_words_range` to highlight matched words in the matched ayah.

Starter integration snippet (JavaScript):

```javascript
const matchesForAyah = (rows, ayahKey) =>
  rows
    .filter((row) => row.verse_key === ayahKey)
    .sort((a, b) => b.score - a.score || b.coverage - a.coverage);

const summaryText = (row) =>
  `This ayah matches ${row.matched_words_count} words with ${row.coverage}% coverage and a similarity score of ${row.score}`;

const isMatchedWordPosition = (wordIndexOneBased, range) => {
  if (!Array.isArray(range) || range.length !== 2) return false;
  const [from, to] = range;
  return wordIndexOneBased >= from && wordIndexOneBased <= to;
};
```

## 6) Real-World Example: Top Similar Ayahs Panel

Goal:

- User opens an ayah and sees top similar ayahs ranked by score.

Inputs:

- Similar Ayah package
- Quran Script package

Processing:

1. Filter rows by selected `verse_key`.
2. Sort by `score` (and `coverage` as tie-breaker).
3. Join matched ayah text and highlight words by `match_words_range`.
4. Display per-match summary sentence.

Expected output:

- Ranked similarity results that are interpretable, with visible highlighted overlap.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// Preview-aligned sandbox:
// Jump to Ayah -> source ayah card -> similar ayah cards with highlighted matched words.
// Based on the behavior shown in similar-ayah resource 74.

const sourceAyahTextByKey = {
  "1:1": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١",
  "1:3": "ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٣"
};

const similarRows = [
  {
    verse_key: "1:1",
    matched_ayah_key: "27:30",
    matched_words_count: 4,
    coverage: 50,
    score: 80,
    match_words_range: [5, 8]
  },
  {
    verse_key: "1:1",
    matched_ayah_key: "59:22",
    matched_words_count: 2,
    coverage: 15,
    score: 56,
    match_words_range: [12, 13]
  },
  {
    verse_key: "1:1",
    matched_ayah_key: "1:3",
    matched_words_count: 2,
    coverage: 100,
    score: 50,
    match_words_range: [1, 2]
  },
  {
    verse_key: "1:1",
    matched_ayah_key: "41:2",
    matched_words_count: 2,
    coverage: 50,
    score: 50,
    match_words_range: [3, 4]
  },
  {
    verse_key: "1:3",
    matched_ayah_key: "1:1",
    matched_words_count: 2,
    coverage: 100,
    score: 50,
    match_words_range: [3, 4]
  }
];

// Keep literals as UTF-8 Arabic text.
const matchedAyahTextByKey = {
  "27:30": "إِنَّهُۥ مِن سُلَيۡمَٰنَ وَإِنَّهُۥ بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٣٠",
  "59:22": "هُوَ ٱللَّهُ ٱلَّذِي لَآ إِلَٰهَ إِلَّا هُوَۖ عَٰلِمُ ٱلۡغَيۡبِ وَٱلشَّهَٰدَةِۖ هُوَ ٱلرَّحۡمَٰنُ ٱلرَّحِيمُ ٢٢",
  "1:3": "ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٣",
  "41:2": "تَنزِيلٞ مِّنَ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٢",
  "1:1": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١"
};

// Help-aligned schema and sample block (as shown on the resource Help tab).
const helpSchema = [
  { column: "verse_key", type: "TEXT", description: "The ayah key that similar ayahs belongs to (e.g., 1:1)." },
  { column: "matched_ayah_key", type: "TEXT", description: "Matching ayah key that shares similar wording." },
  { column: "matched_words_count", type: "INTEGER", description: "Number of matching words between the two ayahs." },
  { column: "coverage", type: "INTEGER", description: "Percentage of words in the source ayah that matched." },
  { column: "score", type: "INTEGER", description: "Similarity score between the source and matched ayah (0–100)." },
  { column: "match_words_range", type: "TEXT", description: "Word position range in matching ayah that matched with source ayah." }
];

const helpExample = {
  verse_key: "1:1",
  matched_ayah_key: "27:30",
  matched_words_count: 4,
  coverage: 100,
  score: 100,
  match_words_range: [5, 8]
};

const highlightMatchedWords = (ayahText, range) =>
  String(ayahText || "")
    .split(/\s+/)
    .filter(Boolean)
    .map((word, index) => {
      const pos = index + 1;
      const inRange =
        Array.isArray(range) &&
        range.length === 2 &&
        pos >= range[0] &&
        pos <= range[1];
      if (!inRange) return word;
      return `<span style="color:#15803d;font-weight:700;">${word}</span>`;
    })
    .join(" ");

const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Similar Ayah Preview</h3>
  <p style="margin:0 0 12px;color:#475569;">Preview + Help on one screen: interactive similar-ayah cards and schema/sample reference</p>
  <div style="margin:0 0 10px;padding:8px 10px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;color:#334155;">
    Top section mirrors <strong>Preview</strong>. Bottom section mirrors the <strong>Help</strong> field/schema explanation.
  </div>
  <div style="margin-bottom:12px;">
    <label for="ayah" style="display:block;margin-bottom:6px;font-weight:700;color:#0f172a;">Jump to Ayah</label>
    <div style="position:relative;max-width:240px;">
      <select id="ayah" style="width:100%;appearance:none;-webkit-appearance:none;margin:0;padding:10px 38px 10px 12px;border:1px solid #94a3b8;border-radius:10px;background:linear-gradient(180deg,#ffffff 0%,#f8fafc 100%);color:#0f172a;font-weight:600;box-shadow:0 1px 2px rgba(15,23,42,0.08);cursor:pointer;outline:none;">
        <option value="1:1">1:1</option>
        <option value="1:3">1:3</option>
      </select>
      <span aria-hidden="true" style="position:absolute;right:12px;top:50%;transform:translateY(-50%);color:#475569;font-size:12px;pointer-events:none;">▼</span>
    </div>
    <div style="margin-top:4px;font-size:12px;color:#64748b;">Select the source ayah to compare similar matches.</div>
  </div>
  <div id="source" style="margin-bottom:10px;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;" dir="rtl"></div>
  <div id="summary" style="margin-bottom:10px;padding:10px 12px;border:1px solid #86efac;border-radius:8px;background:#dcfce7;color:#14532d;"></div>
  <div id="result" style="margin-bottom:12px;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
  <div id="help" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const ayahSelect = app.querySelector("#ayah");
const source = app.querySelector("#source");
const summary = app.querySelector("#summary");
const result = app.querySelector("#result");
const help = app.querySelector("#help");

const render = () => {
  const key = ayahSelect.value;
  source.innerHTML = `
    <div style="display:inline-block;margin-bottom:8px;padding:2px 8px;border-radius:999px;background:#334155;color:#fff;font-size:12px;" dir="ltr">${key}</div>
    <div style="font-family:'Noto Naskh Arabic','Amiri Quran','Scheherazade New','Geeza Pro','Arial Unicode MS',serif;line-height:1.9;">${sourceAyahTextByKey[key] || ""}</div>
  `;

  const rows = similarRows
    .filter((r) => r.verse_key === key)
    .sort((a, b) => b.score - a.score || b.coverage - a.coverage);

  summary.textContent = `${key} has ${rows.length} similar ayahs`;

  if (rows.length === 0) {
    result.textContent = "No similar ayahs found.";
    return;
  }

  result.innerHTML = rows
    .map((r) => {
      const ayahText = matchedAyahTextByKey[r.matched_ayah_key] || "";
      return `
        <div style="margin-bottom:10px;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;">
          <div style="display:inline-block;margin-bottom:8px;padding:2px 8px;border-radius:999px;background:#334155;color:#fff;font-size:12px;">${r.matched_ayah_key}</div>
          <div dir="rtl" style="margin-bottom:8px;font-family:'Noto Naskh Arabic','Amiri Quran','Scheherazade New','Geeza Pro','Arial Unicode MS',serif;line-height:1.9;">
            ${highlightMatchedWords(ayahText, r.match_words_range)}
          </div>
          <small style="color:#475569;">
            This ayah matches ${r.matched_words_count} words with ${r.coverage}% coverage and a similarity score of ${r.score}
          </small>
        </div>
      `;
    })
    .join("");

  const schemaRows = helpSchema
    .map(
      (field) => `
        <tr>
          <td style="padding:6px;border-bottom:1px solid #e2e8f0;"><code>${field.column}</code></td>
          <td style="padding:6px;border-bottom:1px solid #e2e8f0;">${field.type}</td>
          <td style="padding:6px;border-bottom:1px solid #e2e8f0;">${field.description}</td>
        </tr>
      `
    )
    .join("");

  help.innerHTML = `
    <h4 style="margin:0 0 8px;">Help Reference (Schema + Example)</h4>
    <p style="margin:0 0 10px;color:#475569;">QUL exports similar ayah data in JSON and SQLite. Core fields:</p>
    <div style="overflow:auto;margin-bottom:10px;">
      <table style="width:100%;border-collapse:collapse;font-size:14px;">
        <thead>
          <tr style="background:#f8fafc;">
            <th style="text-align:left;padding:6px;border-bottom:1px solid #e2e8f0;">Column</th>
            <th style="text-align:left;padding:6px;border-bottom:1px solid #e2e8f0;">Type</th>
            <th style="text-align:left;padding:6px;border-bottom:1px solid #e2e8f0;">Description</th>
          </tr>
        </thead>
        <tbody>${schemaRows}</tbody>
      </table>
    </div>
    <div style="margin-bottom:6px;"><strong>Help sample</strong> (if <code>1:1</code> matches <code>27:30</code>):</div>
    <pre style="margin:0 0 8px;padding:10px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;overflow:auto;">${JSON.stringify(helpExample, null, 2)}</pre>
    <div style="padding:8px 10px;border:1px solid #bfdbfe;border-radius:8px;background:#eff6ff;color:#1e3a8a;">
      This ayah matches <strong>${helpExample.matched_words_count} words</strong>, with <strong>${helpExample.coverage}% coverage</strong> and a <strong>similarity score of ${helpExample.score}</strong>.
      Word <strong>${helpExample.match_words_range[0]} to ${helpExample.match_words_range[1]}</strong> matched with source ayah.
    </div>
  `;
};

ayahSelect.addEventListener("change", render);
render();
```

## 7) Common Mistakes to Avoid

- Treating similarity score as strict equivalence.
- Ignoring coverage and matched-word context.
- Not sorting results (raw order can be misleading).

## 8) When to Request Updates or Changes

Open an issue if you find:

- Mismatched `verse_key`/`matched_ayah_key` pairs
- Invalid score/coverage values
- Broken json/sqlite downloads

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Similar Ayah Guide](resource-similar-ayah.md)
- [Mutashabihat Guide](resource-mutashabihat.md)
- [Quran Script Guide](resource-quran-script.md)
