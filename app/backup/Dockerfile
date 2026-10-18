FROM postgres:17-alpine

COPY backup.sh restore.sh entrypoint.sh nfs-dir.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p /backups && chown postgres:postgres /backups
VOLUME /backups
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
