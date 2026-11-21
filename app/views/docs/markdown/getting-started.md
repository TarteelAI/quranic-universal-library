# Getting Started

This guide is for users who want to download QUL resources and use them in their own applications.

You can start here without cloning the repository or running QUL locally.

## Before You Start (Important Clarifications)

- You usually do **not** need to clone the QUL repository to use resources.
- QUL is primarily a downloadable resource platform (not a hosted public API service).
- Resource schemas are related but not always identical, so inspect fields before integration.
- Use JSON for speed of integration and SQLite for larger, query-heavy workloads.

## What You Can Build

- Quran reader apps (Arabic + translation)
- Verse/topic search experiences
- Tafsir exploration features
- Word-by-word learning tools (root, lemma, POS)
- NLP/AI pipelines using structured Quran datasets

## 5-Minute Quick Start (Resource Users)

1. Open the resources directory: [/resources](/resources)
2. Pick a dataset category (start with Quran Script or Translation).
3. Choose format:
   - JSON for quick integration and scripts
   - SQLite for larger datasets and query-heavy usage
4. Download the file(s).
5. Load data in your app and render one ayah.

## Common Dataset Categories

- Quran Script: [/resources/quran-script](/resources/quran-script)
- Translations: [/resources/translation](/resources/translation)
- Tafsir: [/resources/tafsir](/resources/tafsir)
- Recitations: [/resources/recitation](/resources/recitation)
- Morphology: [/resources/morphology](/resources/morphology)
- Topics: [/resources/ayah-topics](/resources/ayah-topics)
- Metadata: [/resources/quran-metadata](/resources/quran-metadata)

## Minimal Load Example

### JavaScript

```javascript
const fs = require("fs")
const data = JSON.parse(fs.readFileSync("data.json", "utf8"))
console.log(data["1:1"])
```

### Python

```python
import json

with open("data.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print(data["1:1"])
```

## Identifiers to Learn First

Most JSON exports are objects keyed by location, not arrays, so `data["1:1"]` is the first ayah of Al-Fatihah. Every dataset joins on the same two keys:

- **Ayah key** `surah:ayah`, for example `"2:255"`. The JSON key of ayah-level exports.
- **Word location** `surah:ayah:word`, for example `"1:1:2"`. The JSON key of word-level exports.

SQLite tables split these into number columns, and the names vary by export: `surah` / `ayah` / `word` (Quran script), `sura` / `ayah` (translations), `surah_number` / `ayah_number` / `word_number` (metadata, recitations, word-by-word translations). Check the Docs tab of each resource for its exact columns.

For details, see [data-model.md](data-model.md).

## Next Pages

- Detailed download and format guidance: [downloading-data.md](downloading-data.md)
- Category-by-category overview: [datasets.md](datasets.md)
- Canonical step-by-step implementations: [tutorials.md](tutorials.md)
- Common questions: [faq.md](faq.md)
