#!/bin/bash
# One backup of the atenea stack: Moodle's database and its files, saved
# under the same timestamp so they are always restored as a pair.
set -euo pipefail

DIR="${BACKUP_DIR:-/backups}"
DATAROOT="${MOODLE_DATAROOT:-/var/www/moodledata}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
stamp=$(date +%Y%m%d-%H%M%S)
db_file="moodle-db-$stamp.sql.gz"
files_file="moodle-files-$stamp.tar.gz"
mkdir -p "$DIR"

# The password goes in a private options file, never on the command line,
# so it never shows up in the process list.
cnf=$(mktemp)
trap 'rm -f "$cnf" "$DIR/.$db_file" "$DIR/.$files_file"' EXIT
printf '[client]\nhost=%s\nuser=%s\npassword=%s\n' \
    "${MOODLE_DB_HOST:-db}" "${MOODLE_DB_USER:-moodle}" \
    "$(cat "$MOODLE_DB_PASSWORD_FILE")" > "$cnf"

# 1. The database, as one consistent snapshot that doesn't block Moodle.
mariadb-dump --defaults-extra-file="$cnf" --single-transaction --quick \
    "${MOODLE_DB_NAME:-moodle}" | gzip > "$DIR/.$db_file"

# 2. The files, without what Moodle rebuilds by itself.
tar -czf "$DIR/.$files_file" -C "$DATAROOT" \
    --exclude=./cache --exclude=./temp --exclude=./trashdir .

# A backup that cannot be read is not a backup: check both before keeping.
gzip -t "$DIR/.$db_file"
tar -tzf "$DIR/.$files_file" > /dev/null
mv "$DIR/.$db_file" "$DIR/$db_file"
mv "$DIR/.$files_file" "$DIR/$files_file"

find "$DIR" -name 'moodle-*' -mtime +"$KEEP_DAYS" -delete
echo "backup: ok $stamp, database $(du -h "$DIR/$db_file" | cut -f1), files $(du -h "$DIR/$files_file" | cut -f1)"
