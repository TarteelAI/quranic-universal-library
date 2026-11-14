# Tutorial 7: Quran Metadata End-to-End

This tutorial is for users who want to use Quran structural metadata (surah/juz/hizb/manzil and related entities) for navigation and filtering.

## 1) What This Resource Is

Quran Metadata resources provide structural reference data for Quran navigation.

Typical metadata includes:

- Surah records
- Juz/Hizb/Rub/Manzil structures
- Ayah-range references and numeric indexes

Primary category:

- [https://qul.tarteel.ai/resources/quran-metadata](https://qul.tarteel.ai/resources/quran-metadata)

## 2) When to Use It

Use metadata resources when you are building:

- Browse-by-Juz/Hizb flows
- Structural navigation menus
- Section headers and contextual reading controls

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/quran-metadata](https://qul.tarteel.ai/resources/quran-metadata).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Preview` tab
   - `Docs` tab
4. Confirm available downloads (`json`, `sqlite`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On metadata detail pages:

- `Preview` tab:
  - Displays current metadata item examples
  - Provides navigation controls where relevant
- `Docs` tab:
  - Documents field definitions and enum values
  - Clarifies how structural references map to Quran sections

Practical meaning:

- Metadata is the navigation layer; script/translation/tafsir are content layers.
- Build filters from metadata, then fetch ayah content via shared keys/ranges.

## 5) Download and Use (Step-by-Step)

1. Download metadata package (`json` or `sqlite`).
2. Import structural tables/records.
3. Read juz ranges from `first_verse_key` / `last_verse_key` (format `surah:ayah`).
4. Build indexes by structure number (e.g., `juz_number`, `hizb_number`).
5. Connect metadata filters to ayah queries.

Starter integration snippet (JavaScript):

```javascript
// The JSON exports are objects keyed by number ("1", "2", ...), not arrays.
// surahs: quran-metadata-surah-name.json, juzs: quran-metadata-juz.json
const buildMetadataIndexes = ({ surahs, juzs }) => {
  const surahById = new Map(Object.values(surahs).map((s) => [s.id, s]));
  const juzByNumber = new Map(Object.values(juzs).map((j) => [j.juz_number, j]));
  return { surahById, juzByNumber };
};

// Resolve ayah range for selected juz.
const getJuzAyahRange = (juzByNumber, juzNumber) => {
  const record = juzByNumber.get(juzNumber);
  if (!record) return null;
  return {
    from: record.first_verse_key, // e.g. "78:1"
    to: record.last_verse_key // e.g. "114:6"
  };
};
```

## 6) Real-World Example: Browse by Juz

Goal:

- User selects a Juz and immediately sees its ayah range.

Inputs:

- Quran Metadata package
- Quran Script package

Processing:

1. User picks `Juz 30`.
2. App resolves range from metadata.
3. App queries and renders ayahs in that range.

Expected output:

- Structural navigation works without manual ayah lookups.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox shows how metadata powers structural browsing.

// Trimmed sample in the same shape as the JSON exports (objects keyed by number).
const juzs = {
  "1": { juz_number: 1, verses_count: 148, first_verse_key: "1:1", last_verse_key: "2:141" },
  "2": { juz_number: 2, verses_count: 111, first_verse_key: "2:142", last_verse_key: "2:252" },
  "30": { juz_number: 30, verses_count: 564, first_verse_key: "78:1", last_verse_key: "114:6" }
};

const surahs = {
  "1": { id: 1, name_simple: "Al-Fatihah", revelation_place: "makkah", verses_count: 7 },
  "2": { id: 2, name_simple: "Al-Baqarah", revelation_place: "madinah", verses_count: 286 },
  "78": { id: 78, name_simple: "An-Naba", revelation_place: "makkah", verses_count: 40 },
  "114": { id: 114, name_simple: "An-Nas", revelation_place: "makkah", verses_count: 6 }
};

const surahById = new Map(Object.values(surahs).map((s) => [s.id, s]));
const juzByNumber = new Map(Object.values(juzs).map((j) => [j.juz_number, j]));

// "78:1" -> 78
const surahOf = (verseKey) => Number(verseKey.split(":")[0]);

const app = document.getElementById("app");
const dropdownStyle = [
  "margin-bottom:12px",
  "padding:8px",
  "border:1px solid #cbd5e1",
  "border-radius:8px",
  "background:#fff",
  "color:#0f172a",
  "font-size:0.95rem",
  "line-height:1.3",
  "min-width:220px"
].join(";");

app.innerHTML = `
  <h3 style="margin:0 0 8px;">Quran Metadata Preview (Browse by Juz)</h3>
  <p style="margin:0 0 12px;color:#475569;">Resolve ayah ranges and boundary surahs from metadata</p>
  <label for="juz" style="display:block;margin-bottom:8px;font-weight:600;">Select Juz</label>
  <select id="juz" style="${dropdownStyle}"></select>
  <div id="result" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const juzSelect = app.querySelector("#juz");
const result = app.querySelector("#result");

[1, 2, 30].forEach((n) => {
  const opt = document.createElement("option");
  opt.value = String(n);
  opt.textContent = `Juz ${n}`;
  juzSelect.appendChild(opt);
});

const render = () => {
  const selected = Number(juzSelect.value);
  const range = juzByNumber.get(selected);
  if (!range) {
    result.textContent = "Range not found";
    return;
  }

  const fromSurah = surahById.get(surahOf(range.first_verse_key))?.name_simple;
  const toSurah = surahById.get(surahOf(range.last_verse_key))?.name_simple;

  result.innerHTML = `
    <div><strong>From:</strong> ${range.first_verse_key} (${fromSurah})</div>
    <div><strong>To:</strong> ${range.last_verse_key} (${toSurah})</div>
    <div><strong>Ayahs:</strong> ${range.verses_count}</div>
  `;
};

juzSelect.addEventListener("change", render);
juzSelect.value = "30";
render();
```

## 7) Common Mistakes to Avoid

- Treating metadata as text content instead of navigation data.
- Hardcoding ranges instead of using metadata package values.
- Ignoring enum fields (for example revelation place) during filtering.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Incorrect structural ranges
- Missing metadata records
- Broken json/sqlite links

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Quran Metadata Guide](resource-quran-metadata.md)
- [Quran Script Guide](resource-quran-script.md)
- [Surah Information Guide](resource-surah-information.md)
