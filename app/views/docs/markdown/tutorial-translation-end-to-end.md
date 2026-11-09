# Tutorial 3: Translation End-to-End

This tutorial is for users who want to download translation data and show Arabic + translated text in a reliable way.

## 1) What This Resource Is

Translation resources provide translated Quran text keyed by ayah, with multiple export formats.

Depending on the selected package, you may get:

- Simple translation text (`JSON` / `SQLite`)
- Footnote-tagged translation (`<sup foot_note="...">`)
- Inline-footnote translation (`[[...]]`)
- Text chunk format for structured rendering

Primary category:

- [https://qul.tarteel.ai/resources/translation](https://qul.tarteel.ai/resources/translation)

## 2) When to Use It

Use translation data when you are building:

- Multilingual Quran readers
- Arabic + translation views for learning apps
- Search and discovery experiences in non-Arabic languages

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/translation](https://qul.tarteel.ai/resources/translation).
2. Keep the default listing order and open the first published card.
3. Confirm the resource detail page includes:
   - `Translation Preview` tab
   - `Help` tab
4. Confirm available download formats shown on the page:
   - `simple.json`
   - `simple.sqlite`
   - Optional footnote/chunk variants (when provided by that translation)

This keeps onboarding concrete without hardcoding a resource ID.

## 4) What the Preview Shows (Website-Aligned)

On the translation detail page:

- `Translation Preview` tab:
  - `Jump to Ayah` selector
  - Previous/next ayah navigation
  - Arabic ayah block + translated text block
- `Help` tab:
  - Export format examples
  - Simple structures (nested array, key-value)
  - Footnote structures (tags, inline notes, text chunks)

Practical meaning:

- If you only need plain text, use a simple format.
- If you need footnotes or formatting control, use footnote-tag/chunk formats.

## 5) Download and Use (Step-by-Step)

1. Download your selected translation package.
2. Inspect what format you received:
   - Simple / inline-footnote JSON: `{ "t": "text" }` by ayah key
   - Footnote-tag JSON: `{ "t": "text with <sup foot_note=\"id\">1</sup>", "f": { "id": "note" } }`
   - Chunks JSON: `{ "t": [ "text", { "type": "i", "text": "..." }, { "type": "f", "text": "1" } ], "f": { "1": "note" } }`
   - SQLite: rows with `sura`, `ayah`, `ayah_key`, `text` (and `footnotes` for footnote formats)
3. Normalize to one stable key format in app code (recommended: `surah:ayah`).
4. Load Quran Script data for Arabic text.
5. Join Arabic + translation rows by the same ayah key.
6. Render translations by format-aware rules.
7. Validate at least 5 consecutive ayahs so you catch format edge cases.

Starter integration snippet (JavaScript):

```javascript
// JSON exports are already keyed by ayah key ("73:4") and can be used as the index.
// SQLite rows (sura, ayah, ayah_key, text) need one stable key like "73:4".
const ayahKeyFromRow = (row) => row.ayah_key || `${row.sura}:${row.ayah}`;

// Build lookup map for fast joins with Arabic script rows.
const buildTranslationIndex = (rows) =>
  rows.reduce((index, row) => {
    index[ayahKeyFromRow(row)] = row.text;
    return index;
  }, {});

// Normalize the different translation payload shapes into one renderable object.
const normalizeTranslationPayload = (payload) => {
  // SQLite `text` column (simple format).
  if (typeof payload === "string") return { text: payload, notes: [] };

  // Chunks format: { t: ["plain", {type: "i", text: "italic"}, {type: "f", text: "1"}], f: { "1": "note" } }
  if (Array.isArray(payload?.t)) {
    const textParts = [];
    const notes = [];
    payload.t.forEach((chunk) => {
      if (typeof chunk === "string") textParts.push(chunk);
      else if (chunk?.type === "f") {
        textParts.push(`[${chunk.text}]`);
        notes.push({ id: chunk.text, text: payload.f?.[chunk.text] || "" });
      } else if (chunk?.text) textParts.push(chunk.text); // i, b, small
    });
    return { text: textParts.join(""), notes };
  }

  // Simple/inline-footnote format: { t: "..." }
  // Footnote-tag format: { t: "...<sup foot_note='x'>1</sup>...", f: { x: "note" } }
  if (typeof payload?.t === "string") {
    const noteIds = [];
    const text = payload.t.replace(/<sup foot_note="([^"]+)">([^<]+)<\/sup>/g, (_, id, label) => {
      noteIds.push(id);
      return `[${label}]`;
    });
    const notes = noteIds.map((id) => ({ id, text: payload.f?.[id] || "" }));
    return { text, notes };
  }

  return { text: "", notes: [] };
};
```

## 6) Real-World Example: Arabic + Translation + Footnotes

Goal:

- User picks an ayah and sees Arabic text plus translation, with footnotes when available.

Inputs:

- Quran Script package (Arabic text)
- Translation package (simple or footnote/chunk format)

Processing:

1. User selects ayah key (example: `73:4`).
2. App loads Arabic text by ayah key.
3. App loads translation payload by same ayah key.
4. App normalizes payload to text + notes.
5. UI renders translation and optional footnote list.

Expected output:

- Arabic and translation stay correctly paired.
- Footnotes are visible when provided.
- Format differences do not break rendering.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This playground mirrors the Translation Preview + Help format ideas.
// It demonstrates simple text, footnote-tags, and chunk-based translation data.

const arabicByAyah = {
  "1:1": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
  "1:2": "ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ",
  "73:4": "أَوۡ زِدۡ عَلَيۡهِ وَرَتِّلِ ٱلۡقُرۡءَانَ تَرۡتِيلًا"
};

// Each value has the same shape as an entry in the matching JSON export.
const translationByAyah = {
  // 1) Simple format: { t }.
  "1:1": { t: "In the name of Allah, the Most Compassionate, the Most Merciful." },

  // 2) Chunks format: { t: [...chunks], f } (f is omitted when there are no footnotes).
  "1:2": {
    t: [
      { type: "i", text: "All praise" },
      " is for Allah, Lord of all worlds."
    ]
  },

  // 3) Footnote-tags format from Help concepts: { t, f }.
  "73:4": {
    t: "and recite the Qur'an in a measured way <sup foot_note=\"77646\">1</sup>.",
    f: {
      "77646": "Measured recitation means deliberate and clear pacing."
    }
  }
};

// Convert tagged footnotes into readable inline markers + footnote list.
const parseTaggedTranslation = (payload) => {
  const noteIds = [];
  const text = payload.t.replace(/<sup foot_note="([^"]+)">([^<]+)<\/sup>/g, (_, id, label) => {
    noteIds.push(id);
    return `[${label}]`;
  });

  const notes = noteIds.map((id) => ({
    id,
    text: payload.f?.[id] || "(missing footnote text)"
  }));

  return { text, notes };
};

// Convert chunks format into display text + footnotes.
// Footnote chunks look like { type: "f", text: "1" }; the note text is in payload.f["1"].
const parseChunksTranslation = (payload) => {
  const parts = [];
  const notes = [];

  payload.t.forEach((chunk) => {
    if (typeof chunk === "string") {
      parts.push(chunk);
      return;
    }
    if (chunk?.type === "f") {
      parts.push(`[${chunk.text}]`);
      notes.push({ id: chunk.text, text: payload.f?.[chunk.text] || "(missing footnote text)" });
      return;
    }
    // i, b and small chunks carry plain text.
    if (chunk?.text) parts.push(chunk.text);
  });

  return { text: parts.join(""), notes };
};

// Normalize all format types to a single output shape for rendering.
const normalizeTranslation = (payload) => {
  if (Array.isArray(payload?.t)) return parseChunksTranslation(payload);
  if (typeof payload?.t === "string") return parseTaggedTranslation(payload);
  return { text: "", notes: [] };
};

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
  <h3 style="margin:0 0 8px;">Translation Preview (Format-Aware)</h3>
  <p style="margin:0 0 12px;color:#475569;">Arabic + translation rendering with simple, chunk, and footnote-tag formats</p>
  <label for="ayah" style="display:block;margin-bottom:8px;font-weight:600;">Jump to Ayah</label>
  <select id="ayah" style="${dropdownStyle}">
    <option value="1:1">1:1</option>
    <option value="1:2">1:2</option>
    <option value="73:4">73:4</option>
  </select>
  <div id="arabic" dir="rtl" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;margin-bottom:10px;font-size:1.15rem;background:#fff;"></div>
  <div id="translation" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
  <ul id="notes" style="margin:10px 0 0;padding-left:18px;color:#334155;"></ul>
`;

const ayahSelect = app.querySelector("#ayah");
const arabicBox = app.querySelector("#arabic");
const translationBox = app.querySelector("#translation");
const notesList = app.querySelector("#notes");

const renderAyah = (ayahKey) => {
  const arabic = arabicByAyah[ayahKey] || "(Arabic not found)";
  const rawTranslation = translationByAyah[ayahKey];
  const normalized = normalizeTranslation(rawTranslation);

  arabicBox.textContent = arabic;
  translationBox.textContent = normalized.text || "(Translation not found)";

  notesList.innerHTML = "";
  normalized.notes.forEach((note) => {
    const li = document.createElement("li");
    li.textContent = `[${note.id}] ${note.text}`;
    notesList.appendChild(li);
  });
};

ayahSelect.addEventListener("change", (event) => renderAyah(event.target.value));
renderAyah(ayahSelect.value);
```

## 7) Common Mistakes to Avoid

- Joining translation rows to Arabic by row order instead of ayah key.
- Assuming every translation package has the same structure.
- Rendering footnote-tag HTML directly without sanitization in production apps.
- Ignoring missing footnote entries or missing ayah keys.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Broken download links or missing format files
- Translation text mapped to the wrong ayah
- Footnote IDs without matching footnote text
- Inconsistent metadata for language/source

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Translations Guide](resource-translations.md)
- [Quran Script Guide](resource-quran-script.md)
- [Downloading and Using Data](downloading-data.md)
- [Data Model](data-model.md)
