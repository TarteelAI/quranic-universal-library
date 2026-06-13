# Tutorial 10: Ayah Topics End-to-End

This tutorial is for users who want to browse Quran content by topics and concept groups.

## 1) What This Resource Is

Ayah Topics resources map topics/concepts to related ayahs and often include topic taxonomy details.

Typical content includes:

- Topic entities (name, category, description)
- Topic-to-ayah mappings
- Topic counts and searchable labels

Primary category:

- [https://qul.tarteel.ai/resources/ayah-topics](https://qul.tarteel.ai/resources/ayah-topics)

## 2) When to Use It

Use ayah-topics data when building:

- Topic-first discovery experiences
- Educational thematic study flows
- Search interfaces by concept/theme

## 3) How to Get Your First Example Resource

1. Open [https://qul.tarteel.ai/resources/ayah-topics](https://qul.tarteel.ai/resources/ayah-topics).
2. Keep default listing order and open the first published card.
3. Confirm page sections include:
   - Topics listing/search area
   - `Help` tab
4. Confirm available download formats (commonly `sqlite` on this resource type).

This keeps onboarding concrete without hardcoded IDs.

## 4) What the Preview Shows (Website-Aligned)

On ayah-topics detail pages:

- Topics pane:
  - Search input for topic names/metadata
  - Topic list with ayah counts
  - Topic detail navigation
- `Help` tab:
  - Explains topic families and usage
  - Documents mapping behavior between topics and ayahs

Practical meaning:

- Topic rows and topic-ayah mapping rows should be treated as separate layers.
- Build topic indexes first, then resolve ayah lists for display.

## 5) Download and Use (Step-by-Step)

1. Download the package (commonly `sqlite`).
2. Import topic tables and mapping tables.
3. Normalize topic IDs and ayah keys.
4. Build searchable topic index.
5. On topic selection, fetch mapped ayah keys and join with script/translation.

Starter integration snippet (JavaScript):

```javascript
const buildTopicIndex = (topics) =>
  topics.reduce((index, topic) => {
    index[topic.topic_id] = topic;
    return index;
  }, {});

const ayahKeysForTopic = (topicAyahMappings, topicId) =>
  topicAyahMappings
    .filter((row) => row.topic_id === topicId)
    .map((row) => row.ayah_key);
```

## 6) Real-World Example: Browse by Topic

Goal:

- User picks a topic and sees related ayahs.

Inputs:

- Ayah Topics package
- Quran Script package

Processing:

1. User searches/selects topic.
2. App loads mapped ayah keys.
3. App resolves ayah text and displays results.

Expected output:

- Topic-driven ayah browsing works with stable mapping.

Interactive preview (temporary sandbox):

You can edit this code for testing. Edits are not saved and may not persist after refresh.

```playground-js
// This sandbox demonstrates topic search and topic->ayah mapping.

const topics = [
  { topic_id: 101, name: "Patience", category: "General", ayahs_count: 3 },
  { topic_id: 102, name: "Prayer", category: "General", ayahs_count: 2 },
  { topic_id: 103, name: "Mercy", category: "Theme", ayahs_count: 2 }
];

const topicAyahMappings = [
  { topic_id: 101, ayah_key: "2:153" },
  { topic_id: 101, ayah_key: "3:200" },
  { topic_id: 101, ayah_key: "39:10" },
  { topic_id: 102, ayah_key: "2:43" },
  { topic_id: 102, ayah_key: "20:14" },
  { topic_id: 103, ayah_key: "7:156" },
  { topic_id: 103, ayah_key: "39:53" }
];

const app = document.getElementById("app");
app.innerHTML = `
  <h3 style="margin:0 0 8px;">Ayah Topics Preview</h3>
  <p style="margin:0 0 12px;color:#475569;">Search a topic and list mapped ayah keys</p>
  <input id="search" placeholder="Search topics..." style="width:100%;margin-bottom:10px;padding:8px;border:1px solid #cbd5e1;border-radius:8px;" />
  <div id="topics" style="margin-bottom:10px;"></div>
  <div id="result" style="padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;"></div>
`;

const searchInput = app.querySelector("#search");
const topicsBox = app.querySelector("#topics");
const resultBox = app.querySelector("#result");

const renderTopics = () => {
  const query = searchInput.value.trim().toLowerCase();
  const filtered = topics.filter((t) => t.name.toLowerCase().includes(query));

  topicsBox.innerHTML = "";
  filtered.forEach((topic) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.textContent = `${topic.name} (${topic.ayahs_count})`;
    btn.style.marginRight = "8px";
    btn.style.marginBottom = "8px";
    btn.style.padding = "6px 10px";
    btn.style.border = "1px solid #cbd5e1";
    btn.style.borderRadius = "8px";
    btn.style.background = "#fff";

    btn.addEventListener("click", () => {
      const ayahKeys = topicAyahMappings.filter((r) => r.topic_id === topic.topic_id).map((r) => r.ayah_key);
      resultBox.innerHTML = `<strong>${topic.name}</strong><br/>Ayah Keys: ${ayahKeys.join(", ") || "none"}`;
    });

    topicsBox.appendChild(btn);
  });

  if (filtered.length === 0) resultBox.textContent = "No topics found for this query.";
};

searchInput.addEventListener("input", renderTopics);
renderTopics();
```

## 7) Common Mistakes to Avoid

- Mixing topic metadata and topic-ayah mapping tables.
- Assuming topic IDs are globally stable across different resources.
- Rendering topic results without pagination for large topic sets.

## 8) When to Request Updates or Changes

Open an issue if you find:

- Broken topic-to-ayah mappings
- Missing topic labels/descriptions
- Broken download links

Issue tracker:

- [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)

## Related Docs

- [Tutorials Index](tutorials.md)
- [Ayah Topics Guide](resource-ayah-topics.md)
- [Quran Script Guide](resource-quran-script.md)
- [Translations Guide](resource-translations.md)
