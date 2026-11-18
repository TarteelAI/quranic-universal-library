# FAQ

## Is there an API?

QUL primarily provides downloadable datasets. Integrators usually package data into their own API or database layer.

## Do I need to clone this repository to use QUL resources?

No. Most users can work directly from downloadable resources at [/resources](/resources).

## Should I choose JSON or SQLite?

- JSON: best for quick scripts and prototypes.
- SQLite: best for larger datasets and query-heavy applications.

## How do I join different resources together?

Join on the ayah key (`"2:255"`) for ayah-level data and the word location (`"1:1:2"`) for word-level data. Most JSON exports are keyed by them.

See [data-model.md](data-model.md) for join guidance.

## What should I do if data looks wrong or missing?

Open an issue with:

- resource URL
- format (JSON/SQLite)
- the ayah key or word location involved (for example `2:255` or `1:1:2`)
- expected vs actual output
- minimal reproducible snippet

## Can I use QUL data commercially?

Each resource has its own licence, shown on its page. Check it before production use. Many resources still show "Licence not yet confirmed": treat those as not cleared until the licence is added.
