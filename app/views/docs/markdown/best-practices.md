# Best Practices

## Data and Schema

- Keep `surah_id`, `ayah_number`, and `word_position` as integers.
- Add indexes for `surah_id + ayah_number` in verse-level tables.
- Keep translations and tafsir in separate tables to support multiple sources and languages.
- Avoid duplicating large text blobs when ID-based references are enough.

## Performance

- Cache frequently requested verse and tafsir payloads.
- Use SQLite/PostgreSQL for large datasets instead of in-memory-only workflows.
- Stream large JSON files instead of loading them entirely.
- Benchmark expensive joins on morphology/topic workloads.

## Data Quality and Validation

- Validate required keys (`surah_id`, `ayah_number`, `word_position`) early.
- Keep a small verification script to test joins across selected resource categories.
- Confirm UTF-8 handling in your runtime, storage, and API outputs.
- Track dataset source/version in your metadata for traceability.

## Documentation Quality

- Keep setup commands copy/paste ready.
- Put new-user steps before advanced implementation details.
- Include likely failure cases and exact remediation commands.
- Keep GitHub markdown files as canonical content for website docs.

## Change Management

- Keep pull requests focused by concern (docs, integrations, feature).
- Add concise release notes when docs change user-facing resource workflows.
