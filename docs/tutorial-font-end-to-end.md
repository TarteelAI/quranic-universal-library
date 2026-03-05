# Tutorial 6: Font End-to-End

This tutorial is for users who want to download Quran font assets and apply them correctly in app/web rendering.

## 1) What This Resource Is

Font resources provide downloadable Quran-related font files used to render script-specific text and glyphs.

Common file types include:

- `woff`
- `woff2`
- `ttf`

Primary category:

- [https://qul.tarteel.ai/resources/font](https://qul.tarteel.ai/resources/font)

## 2) When to Use It

Use font resources when you are building:

- Quran readers with script-specific display requirements
- Word-by-word/Glyph interfaces that depend on a specific font family
- Apps that must match a known Mushaf style

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/font](https://qul.tarteel.ai/resources/font).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Glyph Preview` tab
   - `Help` tab
4. Confirm available download files (`woff`, `woff2`, `ttf`).

This keeps onboarding concrete without hardcoded resource IDs.

## 4) What the Preview Shows (Website-Aligned)

On the font detail page:

- `Glyph Preview` tab:
  - Shows font glyph behavior on sample Quran text
  - Helps validate readability and shaping before download
- `Help` tab:
  - Shows practical usage notes
  - Includes live preview guidance for the selected font

Practical meaning:

- You should validate the chosen font against your target script content.
- You should always define fallbacks in case a user device cannot load the primary font.

## 5) Download and Use (Step-by-Step)

1. Download font files from the resource (`woff2` preferred for web, keep `ttf` for fallback).
2. Place font files in your static/public assets.
3. Register with `@font-face`.
4. Apply the font family to Quran text containers.
5. Validate on desktop + mobile and compare shaping.

Starter integration snippet (CSS + JavaScript):

```javascript
// 1) CSS (inject or place in stylesheet)
const css = `
@font-face {
  font-family: 'qpc-hafs';
  src: url('/fonts/qpc-hafs.woff2') format('woff2'),
       url('/fonts/qpc-hafs.woff') format('woff');
  font-display: swap;
}

.quran-script {
  direction: rtl;
  text-align: right;
  font-family: 'qpc-hafs', 'Amiri Quran', 'Noto Naskh Arabic', serif;
}
`;

// 2) Register style once
const style = document.createElement('style');
style.textContent = css;
document.head.appendChild(style);

// 3) Apply class to verse container
document.getElementById('verse').classList.add('quran-script');
```

## 6) Real-World Example: Font-Safe Verse Rendering

Goal:

- Show one ayah with the selected Quran font and safe fallbacks.

Inputs:

- Font files (`woff2`, `woff`, optional `ttf`)
- Quran Script text

Processing:

1. Load font via `@font-face`.
2. Render ayah in RTL block with configured font stack.
3. Verify character shaping and spacing.

Expected output:

- Verse renders with intended visual style.
- Fallback still renders readable Arabic if primary font is unavailable.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox demonstrates font stack switching for Quran text rendering.

const samples = {
  "1:1": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
  "73:4": "أَوۡ زِدۡ عَلَيۡهِ وَرَتِّلِ ٱلۡقُرۡءَانَ تَرۡتِيلًا"
};

const fontPresets = {
  "qpc-hafs (with fallbacks)": {
    family: "'KFGQPC Uthmanic Script HAFS','Amiri Quran','Noto Naskh Arabic','Scheherazade New',serif",
    candidates: ["KFGQPC Uthmanic Script HAFS", "Amiri Quran", "Noto Naskh Arabic", "Scheherazade New"],
    label: "QPC stack (if installed) + safe fallbacks",
    accent: "#0f766e",
    letterSpacing: "0px",
    fontSize: "1.28rem"
  },
  "Amiri Quran": {
    family: "'Amiri Quran','Noto Naskh Arabic',serif",
    candidates: ["Amiri Quran", "Noto Naskh Arabic"],
    label: "Amiri-first stack",
    accent: "#1d4ed8",
    letterSpacing: "0.1px",
    fontSize: "1.24rem"
  },
  "System fallback": {
    // First font name is intentionally fake to force fallback behavior in demo.
    family: "'QUL Missing Font Demo','Noto Naskh Arabic','Geeza Pro','Tahoma','Arial',serif",
    candidates: ["QUL Missing Font Demo", "Noto Naskh Arabic", "Geeza Pro", "Tahoma", "Arial"],
    label: "System-safe fallback stack (forced fallback demo)",
    accent: "#7c2d12",
    letterSpacing: "0.25px",
    fontSize: "1.2rem"
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
  <h3 style="margin:0 0 8px;">Font Preview (Quran Script)</h3>
  <p style="margin:0 0 12px;color:#475569;">Test verse rendering with different font stacks</p>
  <label for="ayah" style="display:block;margin-bottom:8px;font-weight:600;">Select Ayah</label>
  <select id="ayah" style="${dropdownStyle}">
    <option value="1:1">1:1</option>
    <option value="73:4">73:4</option>
  </select>
  <label for="stack" style="display:block;margin-bottom:8px;font-weight:600;">Font Stack</label>
  <select id="stack" style="${dropdownStyle}"></select>
  <div id="verse" style="direction:rtl;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;text-align:right;font-size:1.25rem;line-height:2;"></div>
`;

const ayahSelect = app.querySelector("#ayah");
const stackSelect = app.querySelector("#stack");
const verseBox = app.querySelector("#verse");

Object.keys(fontPresets).forEach((label) => {
  const opt = document.createElement("option");
  opt.value = label;
  opt.textContent = label;
  stackSelect.appendChild(opt);
});

const render = () => {
  verseBox.textContent = samples[ayahSelect.value] || "";
  const preset = fontPresets[stackSelect.value];
  if (!preset) return;

  verseBox.style.fontFamily = preset.family;
  verseBox.style.fontSize = preset.fontSize;
  verseBox.style.letterSpacing = preset.letterSpacing;
  verseBox.style.borderColor = preset.accent;
  verseBox.style.boxShadow = `inset 0 0 0 1px ${preset.accent}22`;
};

ayahSelect.addEventListener("change", render);
stackSelect.addEventListener("change", render);
stackSelect.value = "qpc-hafs (with fallbacks)";
render();
```

## 7) Common Mistakes to Avoid

- Using a Quran script package without its intended font family.
- Defining only one font and no fallback stack.
- Skipping mobile rendering checks.
- Assuming glyph-style and Unicode-style fonts behave identically.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Broken font download links
- Missing glyph support for expected text
- Incorrect font metadata or unclear usage instructions

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Quran Fonts Guide](resource-fonts.md)
- [Quran Script Guide](resource-quran-script.md)
- [Mushaf Layouts Guide](resource-mushaf-layouts.md)
