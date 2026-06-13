# Tutorial 1: Recitation End-to-End

This tutorial is for users who want to download recitation data and build a minimal synced playback experience.

## 1) What This Resource Is

Recitation resources provide Quran audio and related timing metadata.

Depending on the selected package, you can get:

- Surah-by-surah audio (gapless playback)
- Ayah-by-ayah audio (gapped playback)
- Segment timing arrays used for synchronized word or ayah highlighting

Primary category:

- [https://qul.tarteel.ai/resources/recitation](https://qul.tarteel.ai/resources/recitation)

## 2) When to Use It

Use recitation data when you are building:

- Quran audio players
- Memorization or revision tools
- Reading experiences that sync highlights to playback

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/recitation](https://qul.tarteel.ai/resources/recitation).
2. Open the first published card in the default page order.
3. Confirm the resource detail page includes:
   - A `Recitation` preview tab
   - A `Help` tab with segment format examples
4. Download the available file format (`JSON`, `SQLite`, or both).

This avoids hardcoding a resource ID while keeping onboarding concrete.

## 4) What the Preview Shows (Website-Aligned)

On the recitation detail page, the preview helps you validate usability before download:

- `Recitation` tab:
  - Jump-to-ayah selector
  - Previous/next ayah navigation
  - Audio player with timing-driven highlighting behavior
- `Help` tab:
  - Difference between surah-by-surah and ayah-by-ayah data
  - Segment/timestamp sample formats for integration

Practical meaning:

- If segment arrays are present, you can build synchronized highlighting.
- If segment arrays are absent, treat the resource as audio-only playback.

## 5) Download and Use (Step-by-Step)

1. Download your selected recitation package.
2. Inspect fields before integration:
   - Ayah identity fields (`surah`, `ayah`, or `surah:ayah`)
   - Timing fields (`segments`, `timestamp_from`, `timestamp_to`) when provided
   - Audio pointer field (`audio_url` or equivalent)
3. Normalize to a consistent key in your app.
4. Join recitation rows with Quran text rows using the same ayah key.
5. Build a minimal player loop.
6. Test with at least one full surah.

Starter integration snippet (JavaScript):

```javascript
// Convert mixed source fields into one stable key format (e.g., "2:255").
const normalizeAyahKey = (row) => {
  if (row.ayah_key) return row.ayah_key;
  return `${row.surah}:${row.ayah}`;
};

// Build a quick lookup so playback can find timing/audio by ayah key.
const buildTimingIndex = (recitationRows) => {
  return recitationRows.reduce((index, row) => {
    const key = normalizeAyahKey(row);
    index[key] = {
      audioUrl: row.audio_url,
      from: row.timestamp_from,
      to: row.timestamp_to,
      segments: Array.isArray(row.segments) ? row.segments : []
    };
    return index;
  }, {});
};

// Merge Quran text rows with recitation timing rows for display + sync.
const joinTextWithTiming = (scriptRows, timingIndex) => {
  return scriptRows
    .map((row) => {
      const ayahKey = `${row.surah}:${row.ayah}`;
      return { ...row, ayahKey, timing: timingIndex[ayahKey] || null };
    })
    // Keep only rows we can actually sync.
    .filter((row) => row.timing);
};
```

## 6) Real-World Example: Play One Surah with Live Ayah Highlighting

Goal:

- User plays a surah and sees the currently recited ayah highlighted in real time.

Inputs:

- Recitation resource (audio + timings when available)
- Quran Script resource (ayah text)

Processing:

1. User selects a surah.
2. App loads surah text from Quran Script.
3. App loads matching recitation timing map for the same surah.
4. On each player time update, app finds the active ayah time window.
5. UI updates highlight state for that ayah.

Expected output:

- Audio playback is smooth.
- Highlight transitions follow recitation timing.
- Ayah text and audio stay mapped by the same ayah key.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
const words = [
  { wordKey: "1:1:1", text: "بِسۡمِ", from: 0, to: 2 },
  { wordKey: "1:1:2", text: "ٱللَّهِ", from: 2, to: 4 },
  { wordKey: "1:1:3", text: "ٱلرَّحۡمَٰنِ", from: 4, to: 6 },
  { wordKey: "1:1:4", text: "ٱلرَّحِيمِ", from: 6, to: 8 }
];

const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Word Playback Preview (Real Arabic Text)</h3>
  <p style="margin:0 0 12px;color:#475569;">Simulated timestamp-driven highlighting for Surah 1:1 words</p>
  <ul id="word-list" style="list-style:none;padding:0;margin:0;" dir="rtl"></ul>
`;

const list = app.querySelector("#word-list");
words.forEach((word) => {
  const li = document.createElement("li");
  li.dataset.wordKey = word.wordKey;
  li.style.padding = "8px 10px";
  li.style.marginBottom = "6px";
  li.style.borderRadius = "8px";
  li.style.border = "1px solid #e2e8f0";
  li.style.transition = "all 120ms ease";
  li.style.textAlign = "right";
  li.style.fontSize = "1.2rem";
  li.textContent = word.text;
  list.appendChild(li);
});

let currentSecond = 0;
const totalDuration = words[words.length - 1].to + 1;

const setActiveWord = (second) => {
  const active = words.find((word) => second >= word.from && second < word.to);
  list.querySelectorAll("li").forEach((li) => {
    const isActive = active && li.dataset.wordKey === active.wordKey;
    li.style.background = isActive ? "#dcfce7" : "#ffffff";
    li.style.borderColor = isActive ? "#22c55e" : "#e2e8f0";
    li.style.fontWeight = isActive ? "700" : "400";
  });
};

setActiveWord(currentSecond);
setInterval(() => {
  currentSecond = (currentSecond + 1) % totalDuration;
  setActiveWord(currentSecond);
}, 1000);
```

## 7) Common Mistakes to Avoid

- Assuming all recitations include segments.
- Mixing key formats without normalization.
- Joining recitation to text using row order instead of ayah identity.
- Treating preview success for one ayah as proof that whole-surah mapping is correct.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Broken or inaccessible audio file links
- Segment/timestamp values that do not match audible recitation
- Missing ayah mappings in downloaded files
- Inconsistent reciter or package metadata

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Recitations Guide](resource-recitations.md)
- [Quran Script Guide](resource-quran-script.md)
- [Data Model](data-model.md)
- [Downloading and Using Data](downloading-data.md)
