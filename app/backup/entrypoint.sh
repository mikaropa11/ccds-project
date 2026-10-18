#!/bin/sh
set -eu
. /usr/local/bin/nfs-dir.sh

: "${BACKUP_SCHEDULE:=0 3 * * *}"
: "${BACKUP_DIR:=/backups}"
export BACKUP_DIR
nfs_dir "$BACKUP_DIR"

# crond does not pass the environment to jobs
export -p | grep -E ' (PG[A-Z_]*|BACKUP_[A-Z_]*)=' > /etc/backup.env || true

echo "$BACKUP_SCHEDULE . /etc/backup.env; gosu postgres /usr/local/bin/backup.sh > /proc/1/fd/1 2>&1" \
    > /etc/crontabs/root
echo "backup: schedule '$BACKUP_SCHEDULE', keeping ${BACKUP_KEEP_DAYS:-7} days in $BACKUP_DIR"

if [ "${BACKUP_ON_START:-0}" = "1" ]; then
    gosu postgres /usr/local/bin/backup.sh || echo "backup: initial backup failed" >&2
fi

exec crond -f -l 6
