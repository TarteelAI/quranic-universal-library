# Tutorial 9: Surah Information End-to-End

This tutorial is for users who want to show chapter-level context (names, summaries, key notes) before ayah reading.

## 1) What This Resource Is

Surah Information resources provide chapter metadata and explanatory context.

Typical fields include:

- Surah identity (`surah_id` / number)
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
const buildSurahInfoIndex = (rows) =>
  rows.reduce((index, row) => {
    index[row.surah_id] = row;
    return index;
  }, {});

// Use a proper HTML sanitizer in production; this is only a minimal placeholder.
const sanitizeHtml = (html) =>
  String(html || "")
    .replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, "")
    .replace(/on\w+="[^"]*"/gi, "");

const renderDetailedSections = (surahInfo) => {
  if (Array.isArray(surahInfo.sections) && surahInfo.sections.length > 0) {
    return surahInfo.sections
      .map(
        (section) =>
          `<section><h3>${section.title}</h3><p>${section.text}</p></section>`
      )
      .join("");
  }

  // Some sources provide long-form chapter details as HTML.
  return sanitizeHtml(surahInfo.detailed_html || "");
};

const renderSurahHeader = (container, surahInfo) => {
  if (!surahInfo) {
    container.textContent = "Surah info not found";
    return;
  }

  container.innerHTML = `
    <h2>${surahInfo.name}</h2>
    <p>${surahInfo.short_summary || ""}</p>
    <small>Revelation: ${surahInfo.revelation_place || "unknown"}</small>
    <div>${renderDetailedSections(surahInfo)}</div>
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
2. App fetches chapter info by `surah_id`.
3. App renders intro card, then ayah list.

Expected output:

- Users get chapter context before reading ayah content.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox shows short summary + detailed sectioned content rendering.

const surahInfoById = {
  1: {
    name: "Al-Fatihah",
    language: "English",
    revelation_place: "makkah",
    short_summary:
      "This Surah is named Al-Fatihah because of its subject matter. Fatihah is that which opens a subject or a book or any other thing. In other words, Al-Fatihah is a sort of preface.",
    sections: [
      {
        title: "Name",
        text:
          "This Surah is named Al-Fatihah because of its subject matter. Fatihah is that which opens a subject or a book or any other thing. In other words, Al-Fatihah is a sort of preface."
      },
      {
        title: "Period of Revelation",
        text:
          "Surah Al-Fatihah is one of the very earliest Revelations to the Holy Prophet. As a matter of fact, we learn from authentic traditions that it was the first complete Surah that was revealed to Muhammad (Allah's peace be upon him). Before this, only a few miscellaneous verses were revealed which form parts of Alaq, Muzzammil, Muddaththir, etc."
      },
      {
        title: "Theme",
        text:
          "This Surah is in fact a prayer that Allah has taught to all those who want to make a study of His book. It has been placed at the very beginning of the Quran to teach this lesson to the reader: if you sincerely want to benefit from the Quran, you should offer this prayer to the Lord of the Universe."
      },
      {
        title: "Theme (continued)",
        text:
          "This preface is meant to create a strong desire in the heart of the reader to seek guidance from the Lord of the Universe Who alone can grant it. Thus Al-Fatihah indirectly teaches that the best thing for a man is to pray for guidance to the straight path, to study the Quran with the mental attitude of a seeker searching for the truth, and to recognize the fact that the Lord of the Universe is the source of all knowledge. He should, therefore, begin the study of the Quran with a prayer to Him for guidance."
      },
      {
        title: "Theme (prayer and answer)",
        text:
          "From this theme, it becomes clear that the real relation between Al-Fatihah and the Quran is not that of an introduction to a book but that of a prayer and its answer. Al-Fatihah is the prayer from the servant and the Quran is the answer from the Master to the servant's prayer. The servant prays to Allah to show him guidance and the Master places the whole of the Quran before him in answer to his prayer, as if to say, \"This is the Guidance you begged from Me.\""
      }
    ]
  },
  36: {
    name: "Ya-Sin",
    language: "English",
    revelation_place: "makkah",
    short_summary: "Emphasizes resurrection, signs of Allah, and prophetic warning.",
    sections: [
      {
        title: "Name",
        text: "Named after the disjointed letters Ya-Sin."
      },
      {
        title: "Period of Revelation",
        text: "Makki surah focused on belief and accountability."
      },
      {
        title: "Theme",
        text: "Calls to faith, reflection, and responsibility before Allah."
      }
    ]
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

  // Render all detailed sections so users can see complete chapter context.
  const detailedSections = (info.sections || [])
    .map(
      (section) =>
        `<section style="margin:0 0 10px;">
          <h4 style="margin:0 0 4px;">${section.title}</h4>
          <p style="margin:0;line-height:1.55;">${section.text}</p>
        </section>`
    )
    .join("");

  meta.textContent = `Language: ${info.language} | Revelation: ${info.revelation_place}`;
  card.innerHTML = `
    <h4 style="margin:0 0 8px;">${info.name}</h4>
    <p style="margin:0 0 8px;"><strong>Short summary:</strong> ${info.short_summary}</p>
    <div style="border-top:1px solid #e2e8f0;padding-top:8px;">${detailedSections}</div>
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
