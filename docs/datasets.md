# Datasets

QUL development depends on the mini `quran_dev` dataset.

## What It Includes

- Core Quran structure (chapters, verses, words)
- Selected translations and tafsir metadata/content
- Script and mushaf-related data
- Audio-related metadata needed by the app
- Supporting lookup entities (languages, resources, tags, etc.)

## What It Does Not Include

- Full production dataset
- All historical or high-volume resources

If your feature needs more data coverage, open an issue in the project and describe the missing requirement.

## Where to Download

- Mini SQL dump: `mini_quran_dev.sql.zip`
- Mini binary dump: `mini_quran_dev.dump.zip`

Both are linked in [downloading-data.md](downloading-data.md).
