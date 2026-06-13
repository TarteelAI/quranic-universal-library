# Tutorial 14: Ayah Theme End-to-End

This tutorial is for users who want to show concise thematic summaries for ayah groups.

## 1) What This Resource Is

Ayah Theme resources provide themes linked to one ayah or a range of ayahs.

Typical fields include:

- `theme` text
- range fields (`ayah_from`, `ayah_to` or equivalents)
- keywords/tags
- coverage counts

Primary category:

- [https://qul.tarteel.ai/resources/ayah-theme](https://qul.tarteel.ai/resources/ayah-theme)

## 2) When to Use It

Use ayah-theme data when building:

- Passage summaries
- Theme-first study and reflection flows
- Quick contextual hints above ayah groups

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/ayah-theme](https://qul.tarteel.ai/resources/ayah-theme).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Theme Preview` tab
   - `Help` tab
4. Confirm available download format(s) (commonly `sqlite`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On ayah-theme detail pages:

- `Theme Preview` tab:
  - `Jump to Ayah`
  - Theme summary for selected ayah/range
  - Range coverage hints (for example multiple ayahs)
- `Help` tab:
  - Theme field definitions
  - Range logic (`ayah_from` to `ayah_to`)

Practical meaning:

- Theme entries can represent groups, not only single ayahs.
- You should resolve theme by range inclusion, not exact ayah equality only.

## 5) Download and Use (Step-by-Step)

1. Download ayah-theme package (commonly `sqlite`).
2. Import theme rows with range fields.
3. Build resolver to find matching theme for selected ayah.
4. Render theme text + keywords + covered range.
5. Join with script/translation display context.

Starter integration snippet (JavaScript):

```javascript
const findThemeForAyah = (themeRows, surah, ayah) =>
  themeRows.find((row) =>
    row.surah_number === surah && ayah >= row.ayah_from && ayah <= row.ayah_to
  ) || null;
```

## 6) Real-World Example: Passage Theme Banner

Goal:

- User opens an ayah and sees the current passage theme.

Inputs:

- Ayah Theme package
- Quran Script package

Processing:

1. Resolve current ayah.
2. Find theme row where ayah falls in range.
3. Display theme banner above ayah text.

Expected output:

- Users get quick thematic context for current passage.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox demonstrates ayah-to-theme resolution using ayah ranges.

const themeRows = [
  {
    surah_number: 1,
    ayah_from: 1,
    ayah_to: 7,
    theme: "Supplication to Allah for guidance taught by Allah Himself",
    keywords: ["guidance", "worship", "mercy"]
  },
  {
    surah_number: 73,
    ayah_from: 1,
    ayah_to: 19,
    theme: "Night prayer discipline and preparing for revelation",
    keywords: ["qiyam", "recitation", "steadfastness"]
  }
];

const findTheme = (surah, ayah) =>
  themeRows.find((r) => r.surah_number === surah && ayah >= r.ayah_from && ayah <= r.ayah_to) || null;

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
  <h3 style="margin:0 0 8px;">Ayah Theme Preview</h3>
  <p style="margin:0 0 12px;color:#475569;">Resolve thematic summary by ayah range</p>
  <div style="margin-bottom:12px;">
    <label for="ayah" style="display:block;margin-bottom:8px;font-weight:600;">Jump to Ayah</label>
    <select id="ayah" style="${dropdownStyle}">
      <option value="1:1">1:1</option>
      <option value="1:7">1:7</option>
      <option value="73:4">73:4</option>
    </select>
    <div style="margin-top:4px;font-size:12px;color:#64748b;">Pick an ayah to resolve its theme range.</div>
  </div>
  <div id="theme" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const ayahSelect = app.querySelector("#ayah");
const themeBox = app.querySelector("#theme");

const render = () => {
  const [surahStr, ayahStr] = ayahSelect.value.split(":");
  const surah = Number(surahStr);
  const ayah = Number(ayahStr);
  const row = findTheme(surah, ayah);

  if (!row) {
    themeBox.textContent = "No theme found for selected ayah.";
    return;
  }

  themeBox.innerHTML = `
    <div><strong>Theme:</strong> ${row.theme}</div>
    <div><strong>Range:</strong> ${row.surah_number}:${row.ayah_from} to ${row.surah_number}:${row.ayah_to}</div>
    <div><strong>Keywords:</strong> ${row.keywords.join(", ")}</div>
  `;
};

ayahSelect.addEventListener("change", render);
render();
```

## 7) Common Mistakes to Avoid

- Matching themes only by exact ayah instead of range.
- Ignoring multi-ayah group coverage.
- Showing stale theme when user navigates between ayahs.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Broken range mappings
- Missing theme text/keywords
- Broken download links

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Ayah Theme Guide](resource-ayah-theme.md)
- [Ayah Topics Guide](resource-ayah-topics.md)
- [Quran Script Guide](resource-quran-script.md)
