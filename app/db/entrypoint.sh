#!/bin/sh
set -eu
. /usr/local/bin/nfs-dir.sh

nfs_dir "$PGDATA"
# As postgres: as root the stock entrypoint would chown, which root_squash forbids
exec gosu postgres docker-entrypoint.sh "$@"
