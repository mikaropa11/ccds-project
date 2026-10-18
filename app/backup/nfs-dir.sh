# Creates DIR owned by postgres (uid 70), with or without root_squash on NFS
nfs_dir() {
    gosu postgres mkdir -p "$1" 2>/dev/null || mkdir -p "$1" 2>/dev/null || true
    [ "$(stat -c %u "$1" 2>/dev/null)" = 70 ] || chown postgres:postgres "$1" 2>/dev/null || true
    if [ "$(stat -c %u "$1" 2>/dev/null)" != 70 ]; then
        echo "nfs_dir: cannot create $1 owned by postgres (uid 70)." >&2
        echo "nfs_dir: on the NFS server, run: mkdir -p <dir> && chown 70:70 <dir>" >&2
        exit 1
    fi
}
