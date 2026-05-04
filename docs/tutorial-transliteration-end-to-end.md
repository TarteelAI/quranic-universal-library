# Tutorial 8: Transliteration End-to-End

This tutorial is for users who want to show pronunciation-friendly Quran text in non-Arabic script while preserving ayah mapping.

## 1) What This Resource Is

Transliteration resources provide Quran text transliterated into Latin/non-Arabic writing systems.

Typical entries include:

- `ayah_key` in `surah:ayah`
- Transliteration text for each ayah
- Optional variants by language/provider

Primary category:

- [https://qul.tarteel.ai/resources/transliteration](https://qul.tarteel.ai/resources/transliteration)

## 2) When to Use It

Use transliteration data when you are building:

- Beginner-friendly reading modes
- Pronunciation assistance features
- Arabic + transliteration dual-display UI

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/transliteration](https://qul.tarteel.ai/resources/transliteration).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Transliteration Preview` tab
   - `Help` tab
4. Confirm downloads (`json`, `sqlite`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On transliteration detail pages:

- `Transliteration Preview` tab:
  - `Jump to Ayah`
  - Previous/next ayah navigation
  - Arabic line + transliteration line
- `Help` tab:
  - Data shape keyed by `ayah_key`
  - Field examples for app integration

Practical meaning:

- Transliteration must remain keyed exactly like script/translation for safe joins.
- It is a reading aid layer, not a replacement for script text.

## 5) Download and Use (Step-by-Step)

1. Download transliteration package (`json` or `sqlite`).
2. Normalize and index by `ayah_key`.
3. Join with Quran Script rows by ayah key.
4. Add display mode toggle (Arabic | Transliteration | Both).
5. Validate ayah order and alignment.

Starter integration snippet (JavaScript):

```javascript
const buildTransliterationIndex = (rows) =>
  rows.reduce((index, row) => {
    index[row.ayah_key] = row.text;
    return index;
  }, {});

const joinScriptAndTransliteration = (scriptRows, transliterationIndex) =>
  scriptRows.map((row) => {
    const ayahKey = `${row.surah}:${row.ayah}`;
    return {
      ayahKey,
      arabic: row.text,
      transliteration: transliterationIndex[ayahKey] || null
    };
  });
```

## 6) Real-World Example: Reading Mode Toggle

Goal:

- User toggles transliteration under Arabic text for selected ayah.

Inputs:

- Quran Script data
- Transliteration data

Processing:

1. App resolves selected ayah key.
2. App loads Arabic and transliteration lines by same key.
3. UI toggles transliteration visibility.

Expected output:

- Stable Arabic-transliteration pairing for every ayah.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox demonstrates ayah_key-based transliteration joins.

const scriptByAyah = {
  "1:1": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
  "1:2": "ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَ"
};

const transliterationByAyah = {
  "1:1": "Bismillahi al-rahmani al-rahim",
  "1:2": "Al-hamdu lillahi rabbil alamin"
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
  <h3 style="margin:0 0 8px;">Transliteration Preview</h3>
  <p style="margin:0 0 12px;color:#475569;">Switch between Arabic-only and Arabic + transliteration</p>
  <label for="ayah" style="display:block;margin-bottom:8px;font-weight:600;">Jump to Ayah</label>
  <select id="ayah" style="${dropdownStyle}">
    <option value="1:1">1:1</option>
    <option value="1:2">1:2</option>
  </select>
  <label style="display:block;margin-bottom:6px;"><input type="checkbox" id="show" checked /> Show transliteration</label>
  <div id="arabic" dir="rtl" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;margin-bottom:8px;background:#fff;text-align:right;font-size:1.2rem;line-height:2;"></div>
  <div id="translit" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const ayahSelect = app.querySelector("#ayah");
const showToggle = app.querySelector("#show");
const arabicBox = app.querySelector("#arabic");
const translitBox = app.querySelector("#translit");

const render = () => {
  const key = ayahSelect.value;
  arabicBox.textContent = scriptByAyah[key] || "(Arabic not found)";

  if (showToggle.checked) {
    translitBox.style.display = "block";
    translitBox.textContent = transliterationByAyah[key] || "(Transliteration not found)";
  } else {
    translitBox.style.display = "none";
  }
};

ayahSelect.addEventListener("change", render);
showToggle.addEventListener("change", render);
render();
```

## 7) Common Mistakes to Avoid

- Joining transliteration to script by row order instead of `ayah_key`.
- Showing transliteration without clear mode/toggle controls.
- Mixing ayah-by-ayah and word-by-word formats without normalization.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Missing transliteration rows for known ayahs
- Broken character mapping in transliteration text
- Broken json/sqlite links

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Transliteration Guide](resource-transliteration.md)
- [Quran Script Guide](resource-quran-script.md)
- [Translations Guide](resource-translations.md)
