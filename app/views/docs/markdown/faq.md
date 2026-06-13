# FAQ

## Is there an API?

QUL primarily provides downloadable datasets. Integrators usually package data into their own API or database layer.

## Do I need to clone this repository to use QUL resources?

No. Most users can work directly from downloadable resources at [https://qul.tarteel.ai/resources](https://qul.tarteel.ai/resources).

## Should I choose JSON or SQLite?

- JSON: best for quick scripts and prototypes.
- SQLite: best for larger datasets and query-heavy applications.

## How do I join different resources together?

Start with shared identifiers:

- `surah_id`
- `ayah_number`
- `word_position` (for word-level resources)

See [data-model.md](data-model.md) for join guidance.

## What should I do if data looks wrong or missing?

Open an issue with:

- resource URL
- format (JSON/SQLite)
- exact identifiers involved
- expected vs actual output
- minimal reproducible snippet

## Can I use QUL data commercially?

Check repository license terms and dataset-specific licensing details before production use.
