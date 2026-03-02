# Downloading Data

QUL development uses a **mini dump** (not full production data).

## Available Dumps

- SQL dump zip: `https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.sql.zip`
- Binary dump zip: `https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.dump.zip`

As of **July 28, 2025**:

- SQL zip size: ~`202 MB`
- Binary zip size: ~`131 MB`

## Option A: SQL Restore

```bash
unzip mini_quran_dev.sql.zip
psql -d quran_dev -f mini_quran_dev.sql
```

## Option B: Binary Restore

```bash
unzip mini_quran_dev.dump.zip
pg_restore --no-owner --no-privileges --no-tablespaces --no-acl --dbname quran_dev -v mini_quran_dev.dump
```

## Recommended Choice

- Use **binary dump** first (typically faster restore).
- If binary restore fails due to format/client mismatch, use **SQL dump**.

## Validation

After restore:

```bash
psql -d quran_dev -c "SELECT COUNT(*) FROM quran.verses;"
```

You should see a non-zero count.

## Troubleshooting

- `unsupported version ... in file header`:
  - Use a newer `pg_restore` client (or use SQL dump).
- `role ... does not exist` during SQL restore:
  - Create the missing role, or edit dump ownership statements if needed.
- `schema "quran" does not exist`:
  - Ensure the restore completed successfully.
