#!/bin/bash
# Main process of the backup container: one backup every day at
# BACKUP_TIME (UTC), and optionally one right away on start.
set -euo pipefail

BACKUP_TIME="${BACKUP_TIME:-03:30}"
echo "backup: daily at $BACKUP_TIME UTC, keeping ${BACKUP_KEEP_DAYS:-7} days in ${BACKUP_DIR:-/backups}"

if [ "${BACKUP_ON_START:-0}" = 1 ]; then
    backup.sh || echo "backup: the backup on start failed" >&2
fi

while true; do
    now=$(date +%s)
    next=$(date -d "today $BACKUP_TIME" +%s)
    if [ "$next" -le "$now" ]; then
        next=$(date -d "tomorrow $BACKUP_TIME" +%s)
    fi
    sleep $((next - now))
    backup.sh || echo "backup: failed, will retry tomorrow" >&2
done
