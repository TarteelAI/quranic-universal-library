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

1. Open the resources directory: [https://qul.tarteel.ai/resources](https://qul.tarteel.ai/resources)
2. Pick a dataset category (start with Quran Script or Translation).
3. Choose format:
   - JSON for quick integration and scripts
   - SQLite for larger datasets and query-heavy usage
4. Download the file(s).
5. Load data in your app and render one ayah.

## Common Dataset Categories

- Quran Script: [https://qul.tarteel.ai/resources/quran-script](https://qul.tarteel.ai/resources/quran-script)
- Translations: [https://qul.tarteel.ai/resources/translation](https://qul.tarteel.ai/resources/translation)
- Tafsir: [https://qul.tarteel.ai/resources/tafsir](https://qul.tarteel.ai/resources/tafsir)
- Recitations: [https://qul.tarteel.ai/resources/recitation](https://qul.tarteel.ai/resources/recitation)
- Morphology: [https://qul.tarteel.ai/resources/morphology](https://qul.tarteel.ai/resources/morphology)
- Topics: [https://qul.tarteel.ai/resources/ayah-topics](https://qul.tarteel.ai/resources/ayah-topics)
- Metadata: [https://qul.tarteel.ai/resources/quran-metadata](https://qul.tarteel.ai/resources/quran-metadata)

## Minimal Load Example

### JavaScript

```javascript
const fs = require("fs")
const data = JSON.parse(fs.readFileSync("data.json", "utf8"))
console.log(data[0])
```

### Python

```python
import json

with open("data.json", "r", encoding="utf-8") as f:
    data = json.load(f)

print(data[0])
```

## Identifiers to Learn First

Most datasets can be joined using:

- `surah_id`
- `ayah_number`
- `word_position` (word-level resources)

For details, see [data-model.md](data-model.md).

## Next Pages

- Detailed download and format guidance: [downloading-data.md](downloading-data.md)
- Category-by-category overview: [datasets.md](datasets.md)
- Per-resource step-by-step guides: [resource-guides-index.md](resource-guides-index.md)
- Practical implementations: [tutorials.md](tutorials.md)
- Common questions: [faq.md](faq.md)
