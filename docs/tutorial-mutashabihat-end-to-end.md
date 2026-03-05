# Tutorial 12: Mutashabihat End-to-End

This tutorial is for users who want to integrate phrase-level similarity aids for memorization and comparison.

## 1) What This Resource Is

Mutashabihat resources provide phrase-level similarity mappings across ayahs.

The help model typically includes files such as:

- `phrases.json` (shared phrases)
- `phrase_verses.json` (ayah-to-phrase mappings)

Primary category:

- [https://qul.tarteel.ai/resources/mutashabihat](https://qul.tarteel.ai/resources/mutashabihat)

## 2) When to Use It

Use mutashabihat data when building:

- Memorization revision tools
- Similar phrase comparison views
- Confusion-reduction aids for close ayah wording

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/mutashabihat](https://qul.tarteel.ai/resources/mutashabihat).
2. Keep default listing order and open the first published card.
3. Confirm the detail page includes:
   - `Mutashabihat Preview` tab
   - `Help` tab
4. Confirm available download file(s) (commonly `json`).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On mutashabihat detail pages:

- `Mutashabihat Preview` tab:
  - `Jump to Ayah`
  - Displays similar phrase relationships for selected ayah
  - Shows phrase words and repeat statistics
  - Lists phrase ayahs where the phrase appears
- `Help` tab:
  - Explains `phrases.json` and `phrase_verses.json`
  - Shows lookup flow to retrieve related phrases

Practical meaning:

- You should resolve phrase IDs first, then fetch phrase details.
- Mutashabihat is phrase-level guidance, not full tafsir/translation content.

Concrete example (mutashabihat resource `73`):

- Phrase words:
  - بِسۡمِ
  - ٱللَّهِ
  - ٱلرَّحۡمَٰنِ
  - ٱلرَّحِيمِ
- Summary:
  - This phrase is repeated 2 times in 2 ayahs across 2 surahs.
- Phrase ayahs:
  - `1:1`: بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١
  - `27:30`: إِنَّهُۥ مِن سُلَيۡمَٰنَ وَإِنَّهُۥ بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٣٠

## 5) Download and Use (Step-by-Step)

1. Download mutashabihat dataset (`json`).
2. Load `phrase_verses.json` and `phrases.json`.
3. For selected ayah, fetch phrase IDs from phrase-verses mapping.
4. Resolve phrase IDs to phrase details.
5. Optionally join with script words for visual highlighting.

Starter integration snippet (JavaScript):

```javascript
// Required: load phrases.json, phrase_verses.json, and Quran words data.
const phraseIdsForAyah = (phraseVerses, ayahKey) => phraseVerses[ayahKey] || [];

const phrasesForAyah = (phraseVerses, phrasesById, ayahKey) =>
  phraseIdsForAyah(phraseVerses, ayahKey)
    .map((id) => phrasesById[id])
    .filter(Boolean);

// In phrases.json, each phrase can include:
// - source: where the phrase is first sourced from
// - ayah: a mapping like { "2:23": [[from, to], ...] } for word ranges
const phraseRangesForAyah = (phrase, ayahKey) =>
  phrase?.ayah?.[ayahKey] || [];
```

## 6) Real-World Example: Similar Phrase Helper

Goal:

- User selects an ayah and sees phrase-level similar references.

Inputs:

- `phrases.json`
- `phrase_verses.json`

Processing:

1. Resolve phrase IDs for selected ayah.
2. Load matching phrase entries.
3. Render phrase and related ayah references.
4. On demand (`View all`), show all known ayahs where phrase appears.

Expected output:

- User can compare similar phrase patterns quickly.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox mirrors the Help flow: ayah -> phrase IDs -> phrase objects.
// It also mirrors Preview behavior: Jump to Ayah -> repeated phrase cards -> View all ayahs.

const phraseVerses = {
  "1:1": [7301],
  "27:30": [7301],
  "2:112": [7310, 7311, 7312]
};

const phrasesById = {
  7301: {
    id: 7301,
    words: ["بِسۡمِ", "ٱللَّهِ", "ٱلرَّحۡمَٰنِ", "ٱلرَّحِيمِ"],
    phrase_text: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
    repeated_count: 2,
    ayah_count: 2,
    surah_count: 2,
    phrase_ayahs: [
      { ayah_key: "1:1", text: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١" },
      { ayah_key: "27:30", text: "إِنَّهُۥ مِن سُلَيۡمَٰنَ وَإِنَّهُۥ بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٣٠" }
    ]
  },
  7310: {
    id: 7310,
    words: ["فَلَا", "خَوْفٌ", "عَلَيْهِمْ", "وَلَا"],
    phrase_text: "فَلَا خَوْفٌ عَلَيْهِمْ وَلَا",
    repeated_count: 13,
    ayah_count: 13,
    surah_count: 7,
    phrase_ayahs: [
      { ayah_key: "2:112", text: "فَلَهُۥٓ أَجۡرُهُۥ عِندَ رَبِّهِۦ وَلَا خَوۡفٌ عَلَيۡهِمۡ وَلَا هُمۡ يَحۡزَنُونَ ١١٢" },
      { ayah_key: "2:262", text: "لَّهُمۡ أَجۡرُهُمۡ عِندَ رَبِّهِمۡ وَلَا خَوۡفٌ عَلَيۡهِمۡ وَلَا هُمۡ يَحۡزَنُونَ ٢٦٢" }
    ]
  },
  7311: {
    id: 7311,
    words: ["مَنۡ", "أَسۡلَمَ", "وَجۡهَهُۥ", "لِلَّهِ", "وَهُوَ", "مُحۡسِنٞ"],
    phrase_text: "مَنۡ أَسۡلَمَ وَجۡهَهُۥ لِلَّهِ وَهُوَ مُحۡسِنٞ",
    repeated_count: 2,
    ayah_count: 2,
    surah_count: 2,
    phrase_ayahs: [
      { ayah_key: "2:112", text: "مَنۡ أَسۡلَمَ وَجۡهَهُۥ لِلَّهِ وَهُوَ مُحۡسِنٞ" },
      { ayah_key: "31:22", text: "وَمَن يُسۡلِمۡ وَجۡهَهُۥٓ إِلَى ٱللَّهِ وَهُوَ مُحۡسِنٞ" }
    ]
  },
  7312: {
    id: 7312,
    words: ["أَجْرُهُمْ", "عِندَ", "رَبِّهِمْ", "وَلَا", "خَوْفٌ", "عَلَيْهِمْ", "وَلَا", "هُمْ", "يَحْزَنُونَ"],
    phrase_text: "أَجْرُهُمْ عِندَ رَبِّهِمْ وَلَا خَوْفٌ عَلَيْهِمْ وَلَا هُمْ يَحْزَنُونَ",
    repeated_count: 5,
    ayah_count: 5,
    surah_count: 1,
    phrase_ayahs: [
      { ayah_key: "2:112", text: "فَلَهُۥٓ أَجۡرُهُۥ عِندَ رَبِّهِۦ وَلَا خَوۡفٌ عَلَيۡهِمۡ وَلَا هُمۡ يَحۡزَنُونَ ١١٢" },
      { ayah_key: "2:277", text: "لَهُمۡ أَجۡرُهُمۡ عِندَ رَبِّهِمۡ وَلَا خَوۡفٌ عَلَيۡهِمۡ وَلَا هُمۡ يَحۡزَنُونَ ٢٧٧" }
    ]
  }
};

const ayahTextByKey = {
  "1:1": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ١",
  "27:30": "إِنَّهُۥ مِن سُلَيۡمَٰنَ وَإِنَّهُۥ بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ ٣٠",
  "2:112": "بَلَىٰۚ مَنۡ أَسۡلَمَ وَجۡهَهُۥ لِلَّهِ وَهُوَ مُحۡسِنٞ فَلَهُۥٓ أَجۡرُهُۥ عِندَ رَبِّهِۦ وَلَا خَوۡفٌ عَلَيۡهِمۡ وَلَا هُمۡ يَحۡزَنُونَ ١١٢"
};

const helpSample = {
  phrase_verses: { "2:23": [50, 16379] },
  phrases: {
    "50": {
      surahs: 32,
      ayahs: 70,
      count: 71,
      source: { key: "2:23", from: 15, to: 17 },
      ayah: {
        "19:48": [[4, 6]],
        "2:23": [[15, 17]]
      }
    }
  }
};

const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Mutashabihat Preview (Phrase-Level)</h3>
  <p style="margin:0 0 12px;color:#475569;">Preview behavior + Help data model on one screen</p>
  <div style="margin:0 0 10px;padding:8px 10px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;color:#334155;">
    Start with <strong>1:1</strong> (Bismillah). Then switch to <strong>27:30</strong> or <strong>2:112</strong> to see repeated phrase behavior.
  </div>
  <label style="display:block;margin-bottom:6px;font-weight:600;">Jump to Ayah</label>
  <select id="ayah" style="margin-bottom:10px;padding:8px;border:1px solid #cbd5e1;border-radius:8px;">
    <option value="1:1">1:1</option>
    <option value="27:30">27:30</option>
    <option value="2:112">2:112</option>
  </select>
  <div id="current" style="margin-bottom:8px;color:#475569;"></div>
  <div id="ayah-text" dir="rtl" style="margin-bottom:10px;padding:10px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.8;"></div>
  <div id="result" style="margin-bottom:10px;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
  <div id="lookup" style="margin-bottom:10px;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;"></div>
  <div style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;">
    <div style="margin-bottom:6px;"><strong>Help sample: phrase_verses.json</strong></div>
    <pre id="help-phrase-verses" style="margin:0 0 10px;padding:10px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;overflow:auto;"></pre>
    <div style="margin-bottom:6px;"><strong>Help sample: phrases.json</strong></div>
    <pre id="help-phrases" style="margin:0;padding:10px;border:1px solid #e2e8f0;border-radius:8px;background:#f8fafc;overflow:auto;"></pre>
  </div>
`;

const ayahSelect = app.querySelector("#ayah");
const current = app.querySelector("#current");
const ayahTextBox = app.querySelector("#ayah-text");
const lookup = app.querySelector("#lookup");
const result = app.querySelector("#result");
const helpPhraseVersesBox = app.querySelector("#help-phrase-verses");
const helpPhrasesBox = app.querySelector("#help-phrases");

helpPhraseVersesBox.textContent = JSON.stringify(helpSample.phrase_verses, null, 2);
helpPhrasesBox.textContent = JSON.stringify(helpSample.phrases, null, 2);

const render = () => {
  const key = ayahSelect.value;
  const ids = phraseVerses[key] || [];
  const rows = ids.map((id) => phrasesById[id]).filter(Boolean);
  current.textContent = `Selected ayah: ${key}`;
  ayahTextBox.textContent = ayahTextByKey[key] || "";
  lookup.innerHTML = `
    <div style="margin-bottom:6px;"><strong>Lookup flow (from Help):</strong> ayah -> phrase IDs -> phrase objects</div>
    <div><strong>phrase_verses.json[&quot;${key}&quot;]:</strong> [${ids.join(", ")}]</div>
  `;

  if (rows.length === 0) {
    result.textContent = "No phrase relations found.";
    return;
  }

  result.innerHTML = rows
    .map((r) => {
      const words = r.words
        .map(
          (word) =>
            `<span style="display:inline-block;margin:0 6px 6px 0;padding:4px 8px;border:1px solid #e2e8f0;border-radius:999px;font-family:'Amiri Quran','Noto Naskh Arabic',serif;">${word}</span>`
        )
        .join("");

      const ayahRows = r.phrase_ayahs
        .map(
          (item) =>
            `<li style="margin-bottom:8px;">
              <strong>${item.ayah_key}</strong>
              <div dir="rtl" style="font-family:'Amiri Quran','Noto Naskh Arabic',serif;line-height:1.7;">${item.text}</div>
            </li>`
        )
        .join("");

      return `
        <div style="margin-bottom:8px;">
          <div style="margin-bottom:8px;" dir="rtl">${words}</div>
          <p style="margin:0 0 10px;color:#334155;">This phrase is repeated ${r.repeated_count} times in ${r.ayah_count} ayahs across ${r.surah_count} surahs.</p>
          <button type="button" data-phrase-id="${r.id}" style="margin:0 0 10px;padding:6px 10px;border:1px solid #cbd5e1;border-radius:8px;background:#fff;cursor:pointer;">View all</button>
          <div id="ayahs-${r.id}" style="display:none;">
            <div style="margin-bottom:6px;"><strong>Phrase ayahs</strong></div>
            <ul style="margin:0;padding-left:20px;">${ayahRows}</ul>
          </div>
        </div>
      `;
    })
    .join("");

  result.querySelectorAll("button[data-phrase-id]").forEach((button) => {
    button.addEventListener("click", () => {
      const phraseId = button.getAttribute("data-phrase-id");
      const panel = result.querySelector(`#ayahs-${phraseId}`);
      if (!panel) return;
      const isHidden = panel.style.display === "none";
      panel.style.display = isHidden ? "block" : "none";
      button.textContent = isHidden ? "Hide ayahs" : "View all";
    });
  });
};

ayahSelect.addEventListener("change", render);
render();
```

## 7) Common Mistakes to Avoid

- Treating mutashabihat as ayah-level one-to-one data.
- Ignoring phrase ID indirection.
- Not showing related ayah context alongside phrase matches.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Missing phrase IDs in mappings
- Broken references from phrase ID to phrase object
- Broken json download links

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Mutashabihat Guide](resource-mutashabihat.md)
- [Similar Ayah Guide](resource-similar-ayah.md)
- [Quran Script Guide](resource-quran-script.md)
