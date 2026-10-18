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
file="${1:-$(ls -1 "$DIR"/"$PGDATABASE"-*.dump | sort | tail -n 1)}"
[ -f "$file" ] || file="$DIR/$file"

echo "restore: $file -> $PGDATABASE@$PGHOST"
pg_restore --clean --if-exists --no-owner --dbname="$PGDATABASE" "$file"
echo "restore: done"
