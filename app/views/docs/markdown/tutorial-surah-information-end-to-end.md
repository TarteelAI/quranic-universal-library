# Tutorial 9: Surah Information End-to-End

This tutorial is for users who want to show chapter-level context (names, summaries, key notes) before ayah reading.

## 1) What This Resource Is

Surah Information resources provide chapter metadata and explanatory context.

Typical fields include:

- Surah identity (`surah_number`)
- Names/titles
- Short summary text
- Detailed long-form content (often with sections such as `Name`, `Period of Revelation`, `Theme`)
- Language/source metadata
- Revelation context and related descriptors

Primary category:

- [https://qul.tarteel.ai/resources/surah-info](https://qul.tarteel.ai/resources/surah-info)

## 2) When to Use It

Use surah-info data when building:

- Surah intro cards before ayah list
- Chapter overview pages
- Learning experiences with chapter context

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/surah-info](https://qul.tarteel.ai/resources/surah-info).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Surah Info Preview` tab
   - `Help` tab
4. Confirm available downloads (`csv`, `json`, `sqlite`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On surah-info detail pages:

- `Surah Info Preview` tab:
  - `Jump to Surah`
  - Next/previous surah navigation
  - Short summary paragraph
  - Detailed content blocks (for example `Name`, `Period of Revelation`, `Theme`)
- `Help` tab:
  - Resource purpose and coverage (themes/topics/reasons for revelation/summaries)
  - Format availability (`SQLite`, `CSV`, `JSON`)
  - Note that some records include both short summary and detailed long-form text
  - Note that detailed text may include HTML tags for formatting

Practical meaning:

- Surah-info is chapter-level context, not ayah-level text.
- Use it as a companion layer above script/translation views.

Full Surah 1 example content (from a surah-info detail page, in the same structure users see):

- Intro summary:
  - This Surah is named Al-Fatihah because of its subject matter. Fatihah is that which opens a subject or a book or any other thing. In other words, Al-Fatihah is a sort of preface.
- Name:
  - This Surah is named Al-Fatihah because of its subject matter. Fatihah is that which opens a subject or a book or any other thing. In other words, Al-Fatihah is a sort of preface.
- Period of Revelation:
  - Surah Al-Fatihah is one of the very earliest Revelations to the Holy Prophet. As a matter of fact, we learn from authentic traditions that it was the first complete Surah that was revealed to Muhammad (Allah's peace be upon him). Before this, only a few miscellaneous verses were revealed which form parts of Alaq, Muzzammil, Muddaththir, etc.
- Theme:
  - This Surah is in fact a prayer that Allah has taught to all those who want to make a study of His book. It has been placed at the very beginning of the Quran to teach this lesson to the reader: if you sincerely want to benefit from the Quran, you should offer this prayer to the Lord of the Universe.
  - This preface is meant to create a strong desire in the heart of the reader to seek guidance from the Lord of the Universe Who alone can grant it. Thus Al-Fatihah indirectly teaches that the best thing for a man is to pray for guidance to the straight path, to study the Quran with the mental attitude of a seeker searching for the truth, and to recognize the fact that the Lord of the Universe is the source of all knowledge. He should, therefore, begin the study of the Quran with a prayer to Him for guidance.
  - From this theme, it becomes clear that the real relation between Al-Fatihah and the Quran is not that of an introduction to a book but that of a prayer and its answer. Al-Fatihah is the prayer from the servant and the Quran is the answer from the Master to the servant's prayer. The servant prays to Allah to show him guidance and the Master places the whole of the Quran before him in answer to his prayer, as if to say, "This is the Guidance you begged from Me."

## 5) Download and Use (Step-by-Step)

1. Download selected package (`csv`, `json`, or `sqlite`).
2. Import surah records by surah number.
3. Normalize language/source fields if multiple sources are used.
4. Separate short summary and detailed content fields in your data model.
5. If rendering detailed HTML content, sanitize before output in production.
6. Cache chapter metadata for quick chapter loads.
7. Render intro card before ayah list.

Starter integration snippet (JavaScript):

```javascript
// Each record has: surah_number, surah_name, short_text, text (HTML).
// The JSON export is an object keyed by surah number; CSV/SQLite give an array of rows.
const buildSurahInfoIndex = (rows) =>
  Object.values(rows).reduce((index, row) => {
    index[row.surah_number] = row;
    return index;
  }, {});

// Use a proper HTML sanitizer in production; this is only a minimal placeholder.
const sanitizeHtml = (html) =>
  String(html || "")
    .replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, "")
    .replace(/on\w+="[^"]*"/gi, "");

const renderSurahHeader = (container, surahInfo) => {
  if (!surahInfo) {
    container.textContent = "Surah info not found";
    return;
  }

  // `text` is HTML with <h2> section headings (Name, Period of Revelation, Theme, ...).
  container.innerHTML = `
    <h2>${surahInfo.surah_name}</h2>
    <p>${surahInfo.short_text || ""}</p>
    <div>${sanitizeHtml(surahInfo.text)}</div>
  `;
};
```

## 6) Real-World Example: Chapter Intro Card

Goal:

- Show surah context before rendering ayahs.

Inputs:

- Surah Information package
- Quran Script package

Processing:

1. User opens a surah.
2. App fetches chapter info by `surah_number`.
3. App renders intro card, then ayah list.

Expected output:

- Users get chapter context before reading ayah content.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox shows short summary + detailed HTML content rendering.

// Sample records in the same shape as the JSON export (keyed by surah number).
// Ya-Sin's `text` is trimmed to keep the sample short.
const surahInfoById = {
  1: {
    surah_number: 1,
    surah_name: "Al-Fatihah",
    short_text:
      "This Surah is named Al-Fatihah because of its subject matter. Fatihah is that which opens a subject or a book or any other thing. In other words, Al-Fatihah is a sort of preface.",
    text:
      "<h2>Name</h2><p>This Surah is named Al-Fatihah because of its subject matter. Fatihah is that which opens a subject or a book or any other thing. In other words, Al-Fatihah is a sort of preface.</p><h2>Period of Revelation</h2><p>Surah Al-Fatihah is one of the very earliest Revelations to the Holy Prophet. As a matter of fact, we learn from authentic traditions that it was the first complete Surah that was revealed to Muhammad (Allah's peace be upon him). Before this, only a few miscellaneous verses were revealed which form parts of Alaq, Muzzammil, Muddaththir, etc.</p><h2>Theme</h2><p>This Surah is in fact a prayer that Allah has taught to all those who want to make a study of His book. It has been placed at the very beginning of the Quran to teach this lesson to the reader: if you sincerely want to benefit from the Quran, you should offer this prayer to the Lord of the Universe.</p><p>This preface is meant to create a strong desire in the heart of the reader to seek guidance from the Lord of the Universe Who alone can grant it. Thus Al-Fatihah indirectly teaches that the best thing for a man is to pray for guidance to the straight path, to study the Quran with the mental attitude of a seeker searching for the truth, and to recognize the fact that the Lord of the Universe is the source of all knowledge. He should, therefore, begin the study of the Quran with a prayer to Him for guidance.</p><p>From this theme, it becomes clear that the real relation between Al-Fatihah and the Quran is not that of an introduction to a book but that of a prayer and its answer. Al-Fatihah is the prayer from the servant and the Quran is the answer from the Master to the servant's prayer. The servant prays to Allah to show him guidance and the Master places the whole of the Quran before him in answer to his prayer, as if to say, \"This is the Guidance you begged from Me.\"</p>"
  },
  36: {
    surah_number: 36,
    surah_name: "Ya-Sin",
    short_text:
      "The Surah takes its name from the two letters of the alphabet with which it begins. It is written in English as Yasin, Ya-sin or Yaseen.",
    text:
      "<h2>Name</h2><p>The Surah takes its name from the two letters of the alphabet with which it begins.</p><h2>Period of Revelation</h2><p>A study of the style shows that it was either sent down during the last stage of the middle Makkan period, or it is one of those Surahs, which were sent down during the last stage of the Holy Prophet's stay at Makkah.</p>"
  }
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
  <h3 style="margin:0 0 8px;">Surah Info Preview</h3>
  <p style="margin:0 0 12px;color:#475569;">Render short + detailed chapter context before ayah content</p>
  <label for="surah" style="display:block;margin-bottom:8px;font-weight:600;">Jump to Surah</label>
  <select id="surah" style="${dropdownStyle}">
    <option value="1">1</option>
    <option value="36">36</option>
  </select>
  <div id="meta" style="margin-bottom:8px;color:#475569;"></div>
  <div id="card" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const surahSelect = app.querySelector("#surah");
const meta = app.querySelector("#meta");
const card = app.querySelector("#card");

const render = () => {
  const surahId = Number(surahSelect.value);
  const info = surahInfoById[surahId];
  if (!info) {
    meta.textContent = "";
    card.textContent = "Surah info not found";
    return;
  }

  meta.textContent = `Surah ${info.surah_number} | Package: Surah Information (English)`;
  // `text` already holds the detailed sections as HTML (<h2> headings + paragraphs).
  card.innerHTML = `
    <h4 style="margin:0 0 8px;">${info.surah_name}</h4>
    <p style="margin:0 0 8px;"><strong>Short summary:</strong> ${info.short_text}</p>
    <div style="border-top:1px solid #e2e8f0;padding-top:8px;line-height:1.55;">${info.text}</div>
  `;
};

surahSelect.addEventListener("change", render);
render();
```

## 7) Common Mistakes to Avoid

- Treating surah-info as ayah-level content.
- Not handling multiple language/source variants.
- Forgetting to cache chapter metadata for repeated navigations.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Missing/incorrect surah descriptions
- Mismatched surah identifiers
- Broken `csv/json/sqlite` downloads

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Surah Information Guide](resource-surah-information.md)
- [Quran Metadata Guide](resource-quran-metadata.md)
- [Quran Script Guide](resource-quran-script.md)
