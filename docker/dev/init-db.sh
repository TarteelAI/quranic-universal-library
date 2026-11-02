#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE qul_quran_content_dev;
    CREATE DATABASE qul_cms_content_test;
    CREATE DATABASE qul_quran_content_test;
EOSQL

# The Quran content tables live in the quran schema (see config/database.yml).
for db in qul_quran_content_dev qul_quran_content_test; do
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS quran;
EOSQL
done
