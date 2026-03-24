#!/usr/bin/env sh
# run_sqlite.sh - Run a .sql file against an SQLite database
# Usage: ./run_sqlite.sh <database_file>

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <database_file>" >&2
    exit 1
fi

DB_FILE="$1"

if ! command -v sqlite3 > /dev/null 2>&1; then
    echo "Error: sqlite3 is not installed or not in PATH" >&2
    exit 1
fi

DB_DIR="$(dirname "$DB_FILE")"
if [ ! -d "$DB_DIR" ]; then
    echo "Error: Directory does not exist for database file: $DB_DIR" >&2
    exit 1
fi

run_sql() {
    SQL_FILE="$1"
    echo "sqlite3 ${DB_FILE} < ${SQL_FILE}"
    sqlite3 "${DB_FILE}" < "${SQL_FILE}"
}

run_sql ./sql/create_password_table.sql
run_sql ./sql/create_grocery_table.sql
run_sql ./sql/create_vocabulary_table.sql
run_sql ./sql/insert_hsk1_vocabulary.sql
run_sql ./sql/insert_hsk2_vocabulary.sql
run_sql ./sql/insert_hsk3_vocabulary.sql
run_sql ./sql/insert_hsk4_vocabulary.sql
run_sql ./sql/insert_hsk5_vocabulary.sql
run_sql ./sql/insert_hsk6_vocabulary.sql

echo "Done."
