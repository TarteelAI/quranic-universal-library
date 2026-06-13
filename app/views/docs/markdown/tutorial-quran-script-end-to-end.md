# Tutorial 5: Quran Script End-to-End

This tutorial is for users who want to download Quran Script data and render Arabic text reliably in apps.

## 1) What This Resource Is

Quran Script resources provide Arabic Quran text in script-specific formats (for example: word-by-word and ayah-by-ayah variants).

Depending on the selected package, script data can include:

- Verse-level text (`verse_key`, `text`)
- Script metadata (`script_type`, `font_family`)
- Word-level arrays (`words[].position`, `words[].text`, `words[].location`)
- Navigation metadata (`page_number`, `juz_number`, `hizb_number`)

Primary category:

- [https://qul.tarteel.ai/resources/quran-script](https://qul.tarteel.ai/resources/quran-script)

## 2) When to Use It

Use Quran Script data when you are building:

- Arabic Quran readers
- Word-by-word reading and study interfaces
- Features that require stable ayah or word keys for joins (translation, tafsir, audio sync)

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/quran-script](https://qul.tarteel.ai/resources/quran-script).
2. Keep the default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Preview` tab
   - `Help` tab
4. Confirm available downloads:
   - `sqlite`
   - `json`
5. Confirm whether the package is marked `Word by word` or `Ayah by ayah`.

This keeps onboarding concrete without hardcoding a resource ID.

## 4) What the Preview Shows (Website-Aligned)

On the script detail page:

- `Preview` tab:
  - `Jump to Ayah` selector
  - Previous/next ayah navigation
  - Rendered Arabic script output (often word-by-word blocks in word resources)
- `Help` tab:
  - Sample JSON structure
  - Field descriptions (`verse_key`, `text`, `script_type`, `font_family`, `words`)
  - Rendering notes and usage examples (CSS + JS)

Practical meaning:

- You should treat `verse_key` and `words[].location` as canonical join keys.
- You should apply the provided `font_family` (or compatible fallback) for accurate rendering.

## 5) Download and Use (Step-by-Step)

1. Download selected script package (`json` or `sqlite`).
2. Inspect core fields:
   - `verse_key` in `surah:ayah`
   - `text`
   - `script_type`
   - `font_family`
   - `words` (if word-by-word package)
3. Normalize keys in your app:
   - Ayah key: `surah:ayah`
   - Word key: `surah:ayah:word`
4. Store verse and word rows in indexed tables/maps.
5. Join with translation/tafsir/recitation by shared ayah keys.
6. Apply RTL direction + script font in UI.
7. Validate on one full surah and several random ayahs.

Starter integration snippet (JavaScript):

```javascript
// Build fast verse lookup by canonical ayah key.
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

// Render one verse with script-aware font + RTL settings.
const renderVerse = (container, verseRecord) => {
  container.dir = "rtl";
  container.style.textAlign = "right";
  container.style.fontFamily = `${verseRecord.fontFamily || "serif"}, "Amiri Quran", "Noto Naskh Arabic", serif`;
  container.textContent = verseRecord.text;
};

// Optional: render word-by-word blocks when word data exists.
const renderWordBlocks = (container, words) => {
  container.innerHTML = "";
  words
    .slice()
    .sort((a, b) => a.position - b.position)
    .forEach((word) => {
      const chip = document.createElement("span");
      chip.textContent = word.text;
      chip.title = word.location; // e.g., 1:1:2
      chip.style.display = "inline-block";
      chip.style.padding = "6px 10px";
      chip.style.margin = "4px";
      chip.style.border = "1px solid #e2e8f0";
      chip.style.borderRadius = "8px";
      container.appendChild(chip);
    });
};
```

## 6) Real-World Example: Render One Ayah (Verse + Words)

Goal:

- User selects an ayah and sees both full Arabic verse text and word-by-word chips.

Inputs:

- Quran Script package (word-by-word variant)

Processing:

1. User selects ayah key (example: `73:4`).
2. App loads verse row by `verse_key`.
3. App renders full verse text using script-aware font.
4. App renders sorted `words[]` as chips.

Expected output:

- Correct Arabic script display.
- Word order remains stable by `position`.
- Keys remain compatible with translation/tafsir/audio joins.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This playground mirrors Quran Script help concepts:
// verse_key + text + script_type + font_family + words[] with location keys.

const scriptRows = [
  {
    verse_key: "73:4",
    text: "أَوۡ زِدۡ عَلَيۡهِ وَرَتِّلِ ٱلۡقُرۡءَانَ تَرۡتِيلًا",
    script_type: "text_qpc_hafs",
    font_family: "qpc-hafs",
    words: [
      { position: 1, text: "أَوۡ", location: "73:4:1" },
      { position: 2, text: "زِدۡ", location: "73:4:2" },
      { position: 3, text: "عَلَيۡهِ", location: "73:4:3" },
      { position: 4, text: "وَرَتِّلِ", location: "73:4:4" },
      { position: 5, text: "ٱلۡقُرۡءَانَ", location: "73:4:5" },
      { position: 6, text: "تَرۡتِيلًا", location: "73:4:6" }
    ]
  },
  {
    verse_key: "1:1",
    text: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
    script_type: "text_qpc_hafs",
    font_family: "qpc-hafs",
    words: [
      { position: 1, text: "بِسۡمِ", location: "1:1:1" },
      { position: 2, text: "ٱللَّهِ", location: "1:1:2" },
      { position: 3, text: "ٱلرَّحۡمَٰنِ", location: "1:1:3" },
      { position: 4, text: "ٱلرَّحِيمِ", location: "1:1:4" }
    ]
  }
];

// Create verse lookup by verse_key.
const verseByKey = scriptRows.reduce((index, row) => {
  index[row.verse_key] = row;
  return index;
}, {});

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
  <h3 style="margin:0 0 8px;">Quran Script Preview (Verse + Word by Word)</h3>
  <p style="margin:0 0 12px;color:#475569;">Shows how verse_key and words[].location map to rendering + integration keys</p>
  <label for="ayah" style="display:block;margin-bottom:8px;font-weight:600;">Jump to Ayah</label>
  <select id="ayah" style="${dropdownStyle}">
    <option value="73:4">73:4</option>
    <option value="1:1">1:1</option>
  </select>
  <div id="meta" style="margin-bottom:8px;color:#475569;"></div>
  <div id="verse" dir="rtl" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;margin-bottom:10px;background:#fff;text-align:right;font-size:1.2rem;line-height:2;font-family:'KFGQPC Uthmanic Script HAFS','Amiri Quran','Noto Naskh Arabic','Scheherazade New',serif;"></div>
  <div id="words" dir="rtl" style="padding:10px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const ayahSelect = app.querySelector("#ayah");
const metaBox = app.querySelector("#meta");
const verseBox = app.querySelector("#verse");
const wordsBox = app.querySelector("#words");

const renderAyah = (ayahKey) => {
  const verse = verseByKey[ayahKey];
  if (!verse) {
    verseBox.textContent = "(Verse not found)";
    wordsBox.innerHTML = "";
    metaBox.textContent = "";
    return;
  }

  // Show script metadata users should carry into app rendering rules.
  metaBox.textContent = `verse_key: ${verse.verse_key} | script_type: ${verse.script_type} | font_family: ${verse.font_family}`;

  // Full verse rendering.
  verseBox.textContent = verse.text;

  // Word-by-word rendering sorted by position.
  wordsBox.innerHTML = "";
  verse.words
    .slice()
    .sort((a, b) => a.position - b.position)
    .forEach((word) => {
      const chip = document.createElement("span");
      chip.textContent = word.text;
      chip.title = word.location;
      chip.style.display = "inline-block";
      chip.style.padding = "6px 10px";
      chip.style.margin = "4px";
      chip.style.border = "1px solid #e2e8f0";
      chip.style.borderRadius = "8px";
      chip.style.fontFamily = "'KFGQPC Uthmanic Script HAFS','Amiri Quran','Noto Naskh Arabic','Scheherazade New',serif";
      wordsBox.appendChild(chip);
    });
};

ayahSelect.addEventListener("change", (event) => renderAyah(event.target.value));
renderAyah(ayahSelect.value);
```

## 7) Common Mistakes to Avoid

- Joining script data to other resources using row order instead of keys.
- Ignoring `font_family` and then assuming text is wrong when rendering is visually off.
- Treating word-by-word and ayah-by-ayah packages as interchangeable shapes.
- Ignoring `words[].position` and rendering words out of order.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Missing ayah rows or mismatched `verse_key` values
- Broken json/sqlite links for script resources
- Incorrect word order/location keys in word-by-word exports
- Metadata inconsistencies in `script_type` or `font_family`

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Quran Script Guide](resource-quran-script.md)
- [Translations Guide](resource-translations.md)
- [Tafsirs Guide](resource-tafsirs.md)
- [Downloading and Using Data](downloading-data.md)
