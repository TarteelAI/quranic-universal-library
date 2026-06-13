# Resource Guide Template

Use this template when writing or updating any QUL resource documentation page.

## 1) What This Resource Is

- Short definition of the dataset/resource.
- Scope of data it includes.
- Typical formats available (JSON, SQLite, other files).

## 2) When to Use It

- Practical use cases.
- Who benefits most (app developers, educators, researchers, etc.).
- When another resource category may be a better fit.

## 3) How to Download or Access It

1. Open the resource category URL.
2. Select a specific resource package/version.
3. Choose format (JSON/SQLite/etc.).
4. Download and validate file integrity.
5. Inspect fields before integration.

Include:

- Direct category URL.
- Notes on format tradeoffs.
- Any known prerequisites.

## 4) Step-by-Step Integration

1. Load the file.
2. Validate required keys.
3. Store/import in your app database.
4. Add indexes for common lookup fields.
5. Build one minimal feature end-to-end.

## 5) Real-World Usage Example

Include one realistic mini scenario with:

- Goal
- Required resources
- Data flow
- Expected output

## 6) When to Request Updates or Changes

Open an issue when:

- Data appears incorrect or missing.
- Links or downloadable files are broken.
- Required fields are absent/inconsistent.
- You need additional resource coverage.

Issue report should include:

- Resource URL
- Format
- Exact identifiers (`surah_id`, `ayah_number`, `word_position` if relevant)
- Expected vs actual behavior
- Minimal reproducible snippet
