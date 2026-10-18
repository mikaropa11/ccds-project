#!/bin/sh
set -eu

: "${PGHOST:=db}"
: "${PGUSER:=app}"
: "${PGDATABASE:=app}"
export PGHOST PGUSER PGDATABASE
if [ -n "${PGPASSWORD_FILE:-}" ]; then
    PGPASSWORD="$(cat "$PGPASSWORD_FILE")"
    export PGPASSWORD
fi

DIR="${BACKUP_DIR:-/backups}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
name="$PGDATABASE-$(date +%Y%m%d-%H%M%S).dump"
tmp="$DIR/.$name.partial"

mkdir -p "$DIR"
trap 'rm -f "$tmp"' EXIT

pg_dump --format=custom --file="$tmp"
# A dump that pg_restore cannot read is not a backup
pg_restore --list "$tmp" > /dev/null
mv "$tmp" "$DIR/$name"

find "$DIR" -name "$PGDATABASE-*.dump" -mtime +"$KEEP_DAYS" -delete

echo "backup: $(date -Iseconds) ok $name ($(du -h "$DIR/$name" | cut -f1)), $(ls "$DIR"/"$PGDATABASE"-*.dump | wc -l) dumps kept"
