#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE quran_dev;
    CREATE DATABASE quran_community_cms_test;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "quran_dev" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS quran;
EOSQL
