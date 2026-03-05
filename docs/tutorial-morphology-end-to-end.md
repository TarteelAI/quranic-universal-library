# Tutorial 11: Morphology End-to-End

This tutorial is for users who want to integrate word-level Quran morphology (roots, lemmas, grammar tags) into reading/study tools.

## 1) What This Resource Is

Morphology resources provide word-level linguistic annotations for Quran words.

Typical fields include:

- Word location keys (for example `surah:ayah:word`)
- Root/lemma/stem fields
- Part-of-speech and grammar tags

Primary category:

- [https://qul.tarteel.ai/resources/morphology](https://qul.tarteel.ai/resources/morphology)

## 2) When to Use It

Use morphology data when building:

- Tap-word grammar insights
- Root/lemma based search
- Arabic linguistic study tools

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/morphology](https://qul.tarteel.ai/resources/morphology).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Preview` tab (resource-specific title such as `Word root Preview`)
   - `Help` tab
4. Confirm available download formats (commonly `sqlite`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On morphology detail pages:

- `Preview` tab:
  - `Jump to Ayah`
  - Word-level rows for selected ayah (`Word stem`, `Word root`, `Word lemma`)
  - Ayah-level aggregates (`Ayah Stem`, `Ayah Root`, `Ayah Lemma`)
- `Help` tab:
  - Field definitions (including word location key)
  - Integration notes about joining with word-by-word script

Practical meaning:

- Morphology rows must be joined at word-level, not only ayah-level.
- Word order and location keys are mandatory for accurate overlays.

## 5) Download and Use (Step-by-Step)

1. Download morphology package (commonly `sqlite`).
2. Import rows with `word_location`/equivalent keys.
3. Join with Quran Script word data using the same key.
4. Index by root/lemma/POS for search features.
5. Render per-word analysis in UI.

Starter integration snippet (JavaScript):

```javascript
const buildMorphologyIndex = (rows) =>
  rows.reduce((index, row) => {
    index[row.word_location] = row;
    return index;
  }, {});

const enrichWordsWithMorphology = (wordRows, morphologyIndex) =>
  wordRows.map((word) => ({
    ...word,
    morphology: morphologyIndex[word.location] || null
  }));
```

## 6) Real-World Example: Tap Word for Grammar

Goal:

- User taps a Quran word and sees stem/root/lemma details.

Inputs:

- Morphology package
- Quran Script word-by-word package

Processing:

1. Render words with location keys.
2. User taps one word.
3. App resolves morphology row by location key.
4. UI shows stem/root/lemma and ayah-level morphology context.

Expected output:

- Morphology panel reflects the correct tapped word and the ayah-level summary.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.
Tip: scroll down in the preview area to view Ayah Stem/Root/Lemma sections.

```playground-js
// Source-aligned sample for Surah Al-Fatihah (1:1).
// Shows word stem/root/lemma and ayah stem/root/lemma in one preview.
const words = [
  { location: "1:1:1", text: "بِسۡمِ", stem: "سم", root: "س م و", lemma: "اسم" },
  { location: "1:1:2", text: "ٱللَّهِ", stem: "الله", root: "ا ل ه", lemma: "الله" },
  { location: "1:1:3", text: "ٱلرَّحۡمَٰنِ", stem: "رحمان", root: "ر ح م", lemma: "رحمان" },
  { location: "1:1:4", text: "ٱلرَّحِيمِ", stem: "رحيم", root: "ر ح م", lemma: "رحيم" }
];

const ayah = {
  text_with_number: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١",
  text_without_number: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
  stem: "سْمِ اللَّهِ رَّحْمَٰنِ رَّحِيمِ",
  root: "سمو اله رحم رحم",
  lemma: "اسْم اللَّه رَّحْمَٰن رَّحِيم"
};

const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Morphology Preview (Word Level)</h3>
  <p style="margin:0 0 12px;color:#475569;">Surah Al-Fatihah — Ayah 1 (word stem/root/lemma + ayah summary)</p>
  <div style="margin:0 0 10px;padding:8px 10px;border:1px solid #fde68a;border-radius:8px;background:#fffbeb;color:#92400e;">
    Continue scrolling to see Ayah Stem, Ayah Root, and Ayah Lemma.
  </div>
  <button id="jump-ayah" type="button" style="margin:0 0 10px;padding:8px 10px;border:1px solid #cbd5e1;border-radius:8px;background:#fff;cursor:pointer;">
    Scroll to Ayah Sections ↓
  </button>
  <label for="field" style="display:block;margin:0 0 6px;font-weight:600;">Word view</label>
  <select id="field" style="margin-bottom:10px;padding:8px;border:1px solid #cbd5e1;border-radius:8px;">
    <option value="stem">Word Stem</option>
    <option value="root">Word Root</option>
    <option value="lemma">Word Lemma</option>
  </select>
  <div style="overflow:auto;margin-bottom:10px;">
    <table style="width:100%;border-collapse:collapse;">
      <thead>
        <tr>
          <th style="text-align:right;border-bottom:1px solid #e2e8f0;padding:6px;" dir="rtl">Word</th>
          <th style="text-align:right;border-bottom:1px solid #e2e8f0;padding:6px;" dir="rtl">Value</th>
        </tr>
      </thead>
      <tbody id="rows"></tbody>
    </table>
  </div>
  <div id="info" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;margin-bottom:10px;"></div>
  <div id="ayah" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;" dir="rtl"></div>
`;

const fieldSelect = app.querySelector("#field");
const jumpAyahButton = app.querySelector("#jump-ayah");
const rowsBox = app.querySelector("#rows");
const infoBox = app.querySelector("#info");
const ayahBox = app.querySelector("#ayah");
let selectedLocation = "1:1:1";

const renderRows = () => {
  const field = fieldSelect.value;
  rowsBox.innerHTML = "";
  words.forEach((word) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td style="padding:6px;border-bottom:1px solid #f1f5f9;" dir="rtl">
        <button type="button" data-location="${word.location}" style="border:1px solid #cbd5e1;border-radius:8px;padding:4px 8px;background:#fff;font-family:'Amiri Quran','Noto Naskh Arabic',serif;cursor:pointer;">
          ${word.text}
        </button>
      </td>
      <td style="padding:6px;border-bottom:1px solid #f1f5f9;font-family:'Amiri Quran','Noto Naskh Arabic',serif;" dir="rtl">${word[field]}</td>
    `;
    rowsBox.appendChild(tr);
  });

  rowsBox.querySelectorAll("button[data-location]").forEach((btn) => {
    btn.addEventListener("click", () => {
      selectedLocation = btn.getAttribute("data-location");
      renderInfo();
    });
  });
};

const renderInfo = () => {
  const word = words.find((item) => item.location === selectedLocation);
  if (!word) {
    infoBox.textContent = "No morphology found for selected word.";
    return;
  }

  infoBox.innerHTML = `
    <div style="margin-bottom:4px;"><strong>Location:</strong> ${word.location}</div>
    <div style="margin-bottom:4px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;" dir="rtl"><strong>Word:</strong> ${word.text}</div>
    <div style="margin-bottom:4px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;" dir="rtl"><strong>Stem:</strong> ${word.stem}</div>
    <div style="margin-bottom:4px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;" dir="rtl"><strong>Root:</strong> ${word.root}</div>
    <div style="font-family:'Amiri Quran','Noto Naskh Arabic',serif;" dir="rtl"><strong>Lemma:</strong> ${word.lemma}</div>
  `;
};

const renderAyah = () => {
  ayahBox.innerHTML = `
    <div style="margin-bottom:14px;border:1px solid #e2e8f0;border-radius:8px;padding:10px;background:#f8fafc;">
      <div style="margin-bottom:6px;"><strong>Ayah Stem for Surah Al-Fatihah — Ayah 1</strong></div>
      <div style="margin-bottom:8px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;">${ayah.text_with_number}</div>
      <div style="margin-bottom:4px;"><strong>Stem</strong></div>
      <div style="font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;">${ayah.stem}</div>
    </div>
    <div style="margin-bottom:14px;border:1px solid #e2e8f0;border-radius:8px;padding:10px;background:#f8fafc;">
      <div style="margin-bottom:6px;"><strong>Ayah Root for Surah Al-Fatihah — Ayah 1</strong></div>
      <div style="margin-bottom:8px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;">${ayah.text_with_number}</div>
      <div style="margin-bottom:4px;"><strong>Root</strong></div>
      <div style="font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;">${ayah.root}</div>
    </div>
    <div style="border:1px solid #e2e8f0;border-radius:8px;padding:10px;background:#f8fafc;">
      <div style="margin-bottom:6px;"><strong>Ayah Lemma for Surah Al-Fatihah — Ayah 1</strong></div>
      <div style="margin-bottom:8px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;">${ayah.text_without_number}</div>
      <div style="margin-bottom:4px;"><strong>Lemma</strong></div>
      <div style="font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;">${ayah.lemma}</div>
    </div>
  `;
};

fieldSelect.addEventListener("change", renderRows);
jumpAyahButton.addEventListener("click", () => {
  ayahBox.scrollIntoView({ behavior: "smooth", block: "start" });
});
renderRows();
renderInfo();
renderAyah();
```

## 7) Common Mistakes to Avoid

- Joining morphology to verse-only keys instead of word location keys.
- Ignoring word order and position.
- Treating morphology labels as stable across different source datasets.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Incorrect location-key mappings
- Missing stem/root/lemma values
- Broken download links

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Morphology Guide](resource-morphology.md)
- [Quran Script Guide](resource-quran-script.md)
