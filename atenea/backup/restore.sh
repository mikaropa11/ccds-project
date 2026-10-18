#!/bin/bash
# Restores Moodle's database and files from one backup: the timestamp
# given as the first argument, or the latest. Put Moodle in maintenance
# mode before, and purge its caches after.
set -euo pipefail

DIR="${BACKUP_DIR:-/backups}"
DATAROOT="${MOODLE_DATAROOT:-/var/www/moodledata}"
latest=$(ls -1 "$DIR"/moodle-db-*.sql.gz 2>/dev/null | sort | tail -n 1 || true)
stamp="${1:-$(basename "$latest" .sql.gz | sed 's/^moodle-db-//')}"
db_file="$DIR/moodle-db-$stamp.sql.gz"
files_file="$DIR/moodle-files-$stamp.tar.gz"
if [ -z "$stamp" ] || [ ! -f "$db_file" ] || [ ! -f "$files_file" ]; then
    echo "restore: no complete backup '$stamp' in $DIR" >&2
    exit 1
fi

cnf=$(mktemp)
trap 'rm -f "$cnf"' EXIT
printf '[client]\nhost=%s\nuser=%s\npassword=%s\n' \
    "${MOODLE_DB_HOST:-db}" "${MOODLE_DB_USER:-moodle}" \
    "$(cat "$MOODLE_DB_PASSWORD_FILE")" > "$cnf"

echo "restore: database from $(basename "$db_file")"
gunzip -c "$db_file" | mariadb --defaults-extra-file="$cnf" "${MOODLE_DB_NAME:-moodle}"

# Files are restored over the current ones. Moodle names stored files by
# their content, so files added after the backup are simply left unused.
echo "restore: files from $(basename "$files_file")"
tar -xzf "$files_file" -C "$DATAROOT"
chown -R www-data:www-data "$DATAROOT"
echo "restore: done, now purge Moodle's caches"
