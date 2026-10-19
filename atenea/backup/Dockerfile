# Backup job for the atenea stack. Built on the same MariaDB image as the
# database, so the dump tool always matches the server's version.
FROM mariadb:11.4

COPY --chmod=755 entrypoint.sh backup.sh restore.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]