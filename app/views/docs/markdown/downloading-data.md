# Downloading and Using Data

Use this guide when consuming QUL data in your own application or research pipeline.

Resources directory: [https://qul.tarteel.ai/resources](https://qul.tarteel.ai/resources)

Many resources are available in:

- JSON: simple integration, scripts, prototypes
- SQLite: better for larger datasets and query-heavy workflows

SQLite docs: [https://www.sqlite.org/docs.html](https://www.sqlite.org/docs.html)

## Typical Integration Workflow

1. Select a dataset from `/resources`.
2. Download JSON or SQLite.
3. Inspect keys (`surah_id`, `ayah_number`, `word_position`, etc.).
4. Load into your runtime.
5. Import into your database for production workloads.
6. Add indexes on high-traffic query keys.

## Load Examples

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

### Ruby

```ruby
require "json"

data = JSON.parse(File.read("data.json"))
puts data.first
```

## Performance Tips

- Index by `surah_id` + `ayah_number`.
- For large datasets, prefer SQLite or PostgreSQL over in-memory JSON processing.
- Cache frequently accessed verses/tafsir payloads.
- Stream very large JSON files instead of loading full files into memory.

## Troubleshooting

- Download is slow/fails: retry with a stable connection and verify file size after download.
- Schema mismatch in your app: inspect fields first and map keys explicitly.
- Encoding issues: ensure UTF-8 handling in runtime and database.
- Memory issues on large files: prefer SQLite or stream JSON.

## When to Request Updates or Changes

Open a GitHub issue when:

- download links are broken
- files are missing expected records
- key mappings are inconsistent
- you need coverage not available in current packages

Include:

- resource URL
- chosen format (JSON/SQLite)
- identifiers involved (`surah_id`, `ayah_number`, `word_position` if relevant)
- expected vs actual behavior
- a minimal reproducible snippet

Issue tracker: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)
