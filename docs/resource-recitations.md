# Recitations Guide

This guide is for resource users who want to download and integrate Quran recitation datasets from QUL.

Category URL:

- [https://qul.tarteel.ai/resources/recitation](https://qul.tarteel.ai/resources/recitation)

## What This Resource Is

Recitation resources provide Quran audio plus optional timing metadata that can be used for synchronized highlighting.

From the resource preview/help flow, you should expect one of these patterns:

- Surah-by-surah audio (one continuous file per surah)
- Ayah-by-ayah audio (one file per ayah)
- Segment arrays/timestamps for fine-grained sync

## When to Use It

Use recitation data when building:

- Quran playback experiences
- Memorization and revision apps
- Interfaces that highlight ayah or words in sync with audio

## How to Get Your First Example Resource

Use this stable, repeatable selection rule:

1. Open [https://qul.tarteel.ai/resources/recitation](https://qul.tarteel.ai/resources/recitation).
2. Keep the default listing order.
3. Open the first published resource card.
4. Verify the detail page has:
   - `Recitation` preview tab
   - `Help` tab with format samples
5. Download the available format (`JSON`, `SQLite`, or both).

This keeps onboarding concrete without hardcoding a resource ID.

## What the Preview and Help Tabs Show

On the recitation detail page:

- `Recitation` tab:
  - Ayah picker (`Jump to Ayah`)
  - Previous/next ayah navigation
  - Audio player and highlight behavior driven by timing data
- `Help` tab:
  - Surah-by-surah vs ayah-by-ayah recitation explanation
  - Segment format examples and timestamp structures

Integration implication:

- If segment data exists, implement synchronized highlight mode.
- If segment data is absent, support audio playback without forced highlighting.

## Download and Integration Checklist

1. Download the package.
2. Inspect fields in the downloaded file:
   - Ayah identity (`surah`, `ayah`, or `surah:ayah`)
   - Audio pointer (`audio_url`, file path, or equivalent)
   - Timing fields when present (`segments`, `timestamp_from`, `timestamp_to`, duration)
3. Normalize keys before joins:
   - Recommended canonical key: `ayah_key = "#{surah}:#{ayah}"`
4. Load matching Quran text from [Quran Script Guide](resource-quran-script.md).
5. Join recitation rows and Quran text rows by ayah key.
6. Build a minimal playback sequence:
   - Start audio
   - Read current playback timestamp
   - Resolve active ayah or segment
   - Update highlight state
7. Validate on a full surah, not only one ayah.

Starter integration snippet (JavaScript):

```javascript
const normalizeAyahKey = (row) => row.ayah_key || `${row.surah}:${row.ayah}`;

const buildTimingWindows = (recitationRows) =>
  recitationRows.map((row) => ({
    ayahKey: normalizeAyahKey(row),
    from: Number(row.timestamp_from ?? 0),
    to: Number(row.timestamp_to ?? 0),
    segments: Array.isArray(row.segments) ? row.segments : [],
    audioUrl: row.audio_url
  }));

const findActiveAyah = (timings, currentTime) =>
  timings.find((t) => currentTime >= t.from && currentTime < t.to) || null;

const scriptRowByKey = new Map(scriptRows.map((row) => [`${row.surah}:${row.ayah}`, row]));
const timings = buildTimingWindows(recitationRows);

audioElement.addEventListener("timeupdate", () => {
  const active = findActiveAyah(timings, audioElement.currentTime);
  if (!active) return;

  const ayahText = scriptRowByKey.get(active.ayahKey);
  updateHighlightedAyah(active.ayahKey, ayahText);
});
```

## Real-World Usage Example

Goal:

- Play a full surah while highlighting the currently recited ayah.

Required resources:

- Recitation package
- Quran Script package

Flow:

1. User chooses a surah.
2. App loads all ayahs for that surah from Quran Script.
3. App loads recitation timing map for the same surah.
4. During playback, app maps player time to the active ayah window.
5. UI highlights the active ayah and moves as playback progresses.

Expected outcome:

- Audio and text progression stay synchronized.
- Highlight transitions are stable and not delayed/jumping.

Sample input/output for one ayah:

```json
{
  "input": {
    "recitation_row": { "surah": 1, "ayah": 2, "timestamp_from": 2.0, "timestamp_to": 5.0 },
    "script_row": { "surah": 1, "ayah": 2, "text": "Alhamdulillahi Rabbil Alamin" },
    "player_time": 3.4
  },
  "output": {
    "active_ayah_key": "1:2",
    "highlighted_text": "Alhamdulillahi Rabbil Alamin"
  }
}
```

## Common Mistakes

- Assuming every recitation is segmented.
- Joining by row order instead of ayah identity.
- Mixing key styles without normalization.
- Ignoring missing or null timing fields.
- Testing only one ayah and skipping full-surah validation.

## When to Request Updates or Changes

Open an issue when you find:

- Broken audio links or inaccessible files
- Timestamp/segment windows that do not match audible recitation
- Missing ayah mappings in the exported package
- Reciter metadata inconsistencies

Issue link:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Pages

- [Tutorials](tutorials.md)
- [Downloading and Using Data](downloading-data.md)
- [Data Model](data-model.md)
