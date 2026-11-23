# Downloading and Using Data

Use this guide when consuming QUL data in your own application or research pipeline.

Resources directory: [/resources](/resources)

Many resources are available in:

- JSON: simple integration, scripts, prototypes
- SQLite: better for larger datasets and query-heavy workflows

SQLite docs: [https://www.sqlite.org/docs.html](https://www.sqlite.org/docs.html)

## Typical Integration Workflow

1. Select a dataset from `/resources`.
2. Download JSON or SQLite.
3. Inspect keys: JSON is keyed by ayah key (`"1:1"`) or word location (`"1:1:1"`); SQLite column names vary by export.
4. Load into your runtime.
5. Import into your database for production workloads.
6. Add indexes on high-traffic query keys.

## Load Examples

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

### Ruby

```ruby
require "json"

data = JSON.parse(File.read("data.json"))
puts data["1:1"]
```

## Performance Tips

- Index by the ayah key, or by the surah and ayah number columns.
- For large datasets, prefer SQLite or PostgreSQL over in-memory JSON processing.
- Cache frequently accessed verses/tafsir payloads.
- Stream very large JSON files instead of loading full files into memory.
- For exports that reference CDN-hosted assets (for example recitation `audio_url` files on
  `audio-cdn.tarteel.ai`), download them once and serve them from your own storage or CDN.
  Tarteel's CDN is shared infrastructure, not a guaranteed production dependency.

## Troubleshooting

- Download is slow/fails: retry with a stable connection and verify file size after download.
- `audio_url` or other CDN URLs fail at runtime: download the asset once and serve it from your
  own hosting instead of hotlinking Tarteel's CDN.
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
- the ayah key or word location involved (for example `2:255` or `1:1:2`)
- expected vs actual behavior
- a minimal reproducible snippet

Issue tracker: [https://github.com/TarteelAI/quranic-universal-library/issues](https://github.com/TarteelAI/quranic-universal-library/issues)
