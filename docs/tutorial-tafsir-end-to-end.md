# Tutorial 4: Tafsir End-to-End

This tutorial is for users who want to download tafsir data and render ayah-linked commentary reliably.

## 1) What This Resource Is

Tafsir resources provide commentary linked to ayah keys, with support for grouped commentary that can cover multiple ayahs.

Depending on the selected package, tafsir may include:

- Ayah-linked tafsir text
- Grouped tafsir mapping (one main ayah key shared by multiple ayahs)
- Optional HTML formatting tags inside text (`<b>`, `<i>`, etc.)

Primary category:

- [https://qul.tarteel.ai/resources/tafsir](https://qul.tarteel.ai/resources/tafsir)

## 2) When to Use It

Use tafsir data when you are building:

- Ayah detail views with commentary
- Study panels below Arabic/translation text
- Research experiences that compare tafsir sources

## 2A) Tafsir vs Translation

- `Translation` provides direct meaning transfer of ayah text into another language.
- `Tafsir` provides explanation, interpretation, and context around ayah meaning.
- Translation is usually one ayah-to-text mapping, while tafsir can be grouped across multiple ayahs.
- In integration terms: translation is mostly direct key-based rendering; tafsir needs grouped/pointer resolution.

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/tafsir](https://qul.tarteel.ai/resources/tafsir).
2. Keep the default listing order and open the first published card.
3. Confirm the resource detail page includes:
   - `Tafsir Preview` tab
   - `Help` tab
4. Confirm available downloads on the detail page:
   - `json`
   - `sqlite`

This keeps onboarding concrete without hardcoding a resource ID.

## 4) What the Preview Shows (Website-Aligned)

On the tafsir detail page:

- `Tafsir Preview` tab:
  - `Jump to Ayah` selector
  - Previous/next ayah navigation
  - Arabic ayah block + tafsir text block
- `Help` tab:
  - JSON export model for grouped tafsir
  - SQLite columns for grouped/shared commentary
  - Notes about tafsir text including formatting tags

Practical meaning:

- Tafsir is not always one-ayah = one-unique-text.
- Your app must resolve grouped/shared tafsir references correctly.

## 5) Download and Use (Step-by-Step)

1. Download your selected tafsir package (`json` or `sqlite`).
2. Inspect payload shape:
   - JSON keys are ayah keys like `2:3`
   - Value may be an object (main tafsir group) or a string (pointer to group ayah key)
3. Normalize ayah keys in one format (`surah:ayah`).
4. Build a tafsir resolver:
   - If current ayah maps to an object, use its `text`.
   - If current ayah maps to a string, follow that pointer and use the target group text.
5. Join with Quran Script and optionally Translation by ayah key.
6. Render commentary safely (sanitize HTML if rendering tags in production).
7. Validate grouped cases across consecutive ayahs.

Starter integration snippet (JavaScript):

```javascript
// Resolve tafsir text for an ayah key.
// JSON model can be:
// - object: { text, ayah_keys }
// - string: pointer to another ayah key where main text is stored
const resolveTafsirText = (tafsirByAyahKey, ayahKey) => {
  const value = tafsirByAyahKey[ayahKey];
  if (!value) return null;

  // Main group record.
  if (typeof value === "object" && value.text) {
    return {
      groupAyahKey: ayahKey,
      ayahKeys: Array.isArray(value.ayah_keys) ? value.ayah_keys : [ayahKey],
      text: value.text
    };
  }

  // Pointer record. Example: "2:4": "2:3"
  if (typeof value === "string") {
    const main = tafsirByAyahKey[value];
    if (main && typeof main === "object" && main.text) {
      return {
        groupAyahKey: value,
        ayahKeys: Array.isArray(main.ayah_keys) ? main.ayah_keys : [value],
        text: main.text
      };
    }
  }

  return null;
};
```

## 6) Real-World Example: One Tafsir for Multiple Ayahs

Goal:

- User opens an ayah and sees the correct tafsir even when commentary is shared across a range.

Inputs:

- Tafsir package (`json` or `sqlite`)
- Quran Script package

Processing:

1. User selects ayah key (example: `2:4`).
2. App looks up tafsir by ayah key.
3. If value is pointer (`"2:3"`), app resolves to main group record.
4. App renders resolved tafsir text and shows covered ayah keys.

Expected output:

- Correct commentary appears for both main ayah and grouped ayahs.
- No blank tafsir for grouped/pointer ayahs.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This playground mirrors the Help model shown on tafsir detail pages:
// object = main tafsir group, string = pointer to main group ayah key.

const arabicByAyah = {
  "2:3": "ٱلَّذِينَ يُؤۡمِنُونَ بِٱلۡغَيۡبِ وَيُقِيمُونَ ٱلصَّلَوٰةَ وَمِمَّا رَزَقۡنَٰهُمۡ يُنفِقُونَ",
  "2:4": "وَٱلَّذِينَ يُؤۡمِنُونَ بِمَآ أُنزِلَ إِلَيۡكَ وَمَآ أُنزِلَ مِن قَبۡلِكَ وَبِٱلۡأٓخِرَةِ هُمۡ يُوقِنُونَ",
  "2:5": "أُولَٰئِكَ عَلَىٰ هُدًى مِنْ رَبِّهِمْ وَأُولَٰئِكَ هُمُ الْمُفْلِحُونَ"
};

const tafsirByAyahKey = {
  // Main tafsir group record.
  "2:3": {
    text: "The muttaqeen are those who believe in the unseen and remain steadfast in worship.",
    ayah_keys: ["2:3", "2:4"]
  },
  // Pointer record: ayah 2:4 uses tafsir text stored at 2:3.
  "2:4": "2:3",
  // Independent tafsir record.
  "2:5": {
    text: "These are upon guidance from their Lord, and they are the successful.",
    ayah_keys: ["2:5"]
  }
};

// Resolve current ayah to a main tafsir record.
const resolveTafsir = (ayahKey) => {
  const value = tafsirByAyahKey[ayahKey];
  if (!value) return null;

  if (typeof value === "object" && value.text) {
    return { groupAyahKey: ayahKey, text: value.text, ayahKeys: value.ayah_keys || [ayahKey] };
  }

  if (typeof value === "string") {
    const main = tafsirByAyahKey[value];
    if (main && typeof main === "object" && main.text) {
      return { groupAyahKey: value, text: main.text, ayahKeys: main.ayah_keys || [value] };
    }
  }

  return null;
};

const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Tafsir Preview (Grouped Ayah Aware)</h3>
  <p style="margin:0 0 12px;color:#475569;">Demonstrates object + pointer tafsir mapping from the Help format</p>
  <label for="ayah" style="display:block;margin-bottom:8px;font-weight:600;">Jump to Ayah</label>
  <select id="ayah" style="margin-bottom:12px;padding:8px;border:1px solid #cbd5e1;border-radius:8px;">
    <option value="2:3">2:3</option>
    <option value="2:4">2:4 (pointer to 2:3)</option>
    <option value="2:5">2:5</option>
  </select>
  <div id="arabic" dir="rtl" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;margin-bottom:10px;font-size:1.2rem;line-height:2;background:#fff;font-family:'KFGQPC Uthmanic Script HAFS','Amiri Quran','Noto Naskh Arabic','Scheherazade New',serif;"></div>
  <div id="tafsir" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
  <p id="group" style="margin:10px 0 0;color:#475569;"></p>
`;

const ayahSelect = app.querySelector("#ayah");
const arabicBox = app.querySelector("#arabic");
const tafsirBox = app.querySelector("#tafsir");
const groupInfo = app.querySelector("#group");

const renderAyah = (ayahKey) => {
  arabicBox.textContent = arabicByAyah[ayahKey] || "(Arabic not found)";

  const resolved = resolveTafsir(ayahKey);
  if (!resolved) {
    tafsirBox.textContent = "(Tafsir not found)";
    groupInfo.textContent = "";
    return;
  }

  tafsirBox.textContent = resolved.text;
  groupInfo.textContent = `Group source: ${resolved.groupAyahKey} | Covers: ${resolved.ayahKeys.join(", ")}`;
};

ayahSelect.addEventListener("change", (event) => renderAyah(event.target.value));
renderAyah(ayahSelect.value);
```

## 7) Common Mistakes to Avoid

- Assuming every ayah key contains direct tafsir text.
- Ignoring string-pointer records in JSON grouped exports.
- Failing to resolve `group_ayah_key` in SQLite exports.
- Rendering tafsir HTML without sanitization in production apps.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Grouped ayah references pointing to missing source keys
- Tafsir text assigned to wrong ayah ranges
- Broken json/sqlite download links
- Missing or inconsistent source metadata

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Tafsirs Guide](resource-tafsirs.md)
- [Quran Script Guide](resource-quran-script.md)
- [Translations Guide](resource-translations.md)
- [Downloading and Using Data](downloading-data.md)
