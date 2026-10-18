# atenea stack: Moodle

Moodle 5.3, the learning platform, at https://moodle.ccds-project.duckdns.org.
One image runs both the website and Moodle's scheduled tasks. The database is
MariaDB, and a backup job saves the database and Moodle's files every day.

| Service | Image                             | Replicas | Role                                                          |
|---------|-----------------------------------|----------|---------------------------------------------------------------|
| moodle  | `atenea-moodle` (Apache, PHP 8.3) | 2        | the website                                                   |
| cron    | `atenea-moodle`, `moodle-cron`    | 1        | installs or upgrades Moodle, then runs its tasks every minute |
| db      | mariadb:11.4                      | 1        | the database                                                  |
| backup  | `atenea-backup` (MariaDB tools)   | 1        | daily database dump and file archive                          |

`moodle` scales to any number of replicas: sessions live in the database and
Moodle's files on the shared disk, so any replica can serve any user. `cron`
and `backup` have one replica because they are cron jobs, and `db` because it
is the DBMS.

## Secrets
`atenea/secrets/` is gitignored because the repository is public. Create the
three files once on each machine that runs the stack:
```sh
mkdir -p atenea/secrets
openssl rand -hex 24 | tr -d '\n' > atenea/secrets/db_password
openssl rand -hex 24 | tr -d '\n' > atenea/secrets/db_root_password
printf 'Atenea-%s-9Z' "$(openssl rand -hex 8)" > atenea/secrets/admin_password
```
Log in to Moodle as `admin` with the last one. It meets Moodle's password
policy: upper and lower case, a digit and a symbol.

## Local
```sh
docker compose -f atenea/compose.yml up -d --build
docker compose -f atenea/compose.yml logs -f cron   # wait for "moodle-setup: ready"
```
Then open http://localhost:8080. The first start takes a few minutes while
`cron` installs Moodle's database, and the website waits for it.
`docker compose -f atenea/compose.yml down` stops everything and keeps the
data. Adding `-v` deletes the database, Moodle's files and the backups.

## Production
### Build and deploy
On swarm-manager-1, from the repository root, once the basic stack runs:
```sh
sudo docker login ccds-project.duckdns.org
sudo atenea/build.sh
sudo docker stack deploy --with-registry-auth -c atenea/production.yml atenea
sudo docker service logs -f atenea_cron   # wait for "moodle-setup: ready"
```
On the first deploy, Swarm rejects the `moodle` tasks with "bind source path
does not exist" until `cron` has created Moodle's folder. It keeps retrying
on its own, and the website starts once the folder exists.

`moodle` and `db` have healthchecks: Swarm sends traffic only to healthy
replicas and replaces the ones that fail. Each container keeps at most three
log files of 10 MB.

### Where the data lives
| Data                      | Where                                     | Written by        |
|---------------------------|-------------------------------------------|-------------------|
| Moodle's files (dataroot) | `/srv/nfs/atenea/moodledata`, shared disk | `moodle`, `cron`  |
| Backups                   | `/srv/nfs/atenea/backups`, shared disk    | `backup`          |
| Database                  | volume `atenea_dbdata` on swarm-manager-3 | `db`              |
| Sessions                  | the database                              | `moodle`          |
| Local caches              | `/var/cache/moodle` in each container     | rebuilt as needed |

- The NFS export squashes root: on the other nodes, root in a container counts
  as `nobody` on the share. So `cron` and `backup` run on swarm-manager-1, the
  NFS server, where root keeps full rights: `cron` creates Moodle's folder and
  gives it to `www-data`, and `restore.sh` resets its owner. This adds no new
  weak point, because without that node there is no shared disk.
- `cron` and `backup` mount the whole share, the only folder sure to exist
  before the first deploy. The `moodle` replicas face the internet, so they
  mount only Moodle's folder.
- The database stays on the local disk of swarm-manager-3, because databases
  do badly on NFS. The daily backup on the shared disk is its safety net.

### nginx (basic stack)
nginx needs this server block, and the certificate must include
`-d moodle.ccds-project.duckdns.org`. With `resolver` and a variable, nginx
still starts when the atenea stack is not deployed.
```nginx
server {
    listen 443 ssl;
    server_name moodle.ccds-project.duckdns.org;
    ssl_certificate     /etc/letsencrypt/live/ccds-project.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ccds-project.duckdns.org/privkey.pem;
    resolver 127.0.0.11 valid=10s;
    client_max_body_size 200m;   # PHP in the image accepts uploads up to 200 MB

    location / {
        set $moodle http://atenea-moodle:80;
        proxy_pass $moodle;
        proxy_set_header Host $host;   # Moodle redirects any other host name
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```
nginx ends HTTPS, and `MOODLE_SSLPROXY` tells Moodle so.

## Backups
- Every day at 03:30 UTC, `backup` saves a pair under one timestamp in
  `/srv/nfs/atenea/backups`. `moodle-db-<stamp>.sql.gz` is a consistent
  `mariadb-dump` taken without locking Moodle. `moodle-files-<stamp>.tar.gz`
  holds Moodle's files without its caches.
- Both files are tested before they are kept, and pairs older than 7 days
  are deleted.
- A pair is always restored together, because the database lists the files.

### Backup and restore by hand
On swarm-manager-1, where `cron` and `backup` run:
```sh
cron=$(sudo docker ps -q -f name=atenea_cron)
backup=$(sudo docker ps -q -f name=atenea_backup)
sudo docker exec $backup backup.sh   # a backup now
```
To restore, put Moodle in maintenance mode, restore, purge the caches and
leave maintenance mode. A drill on a laptop, bringing back a deleted course,
took 21 seconds.
```sh
sudo docker exec $cron runuser -u www-data -- php admin/cli/maintenance.php --enable
sudo docker exec $backup restore.sh   # the latest pair, or one by its stamp:
                                      #   restore.sh 20261019-033000
sudo docker exec $cron runuser -u www-data -- php admin/cli/purge_caches.php
sudo docker exec $cron runuser -u www-data -- php admin/cli/maintenance.php --disable
```
Locally, the same commands run as `docker compose -f atenea/compose.yml exec`
followed by the service name.

### If swarm-manager-3 is lost
The database's files stay on that node, so `db` cannot move by itself.
1. Put Moodle in maintenance mode by hand, because the maintenance tool needs
   the database. Otherwise visitors would find Moodle's installer.
   `sudo sh -c 'echo "Back soon" > /srv/nfs/atenea/moodledata/climaintenance.html'`
2. Point the `db` constraint in `production.yml` at another node and deploy.
   The database starts empty there.
3. Restore the last pair from before the loss by its stamp, purge the caches
   and leave maintenance mode, as above. Use the stamp: a nightly backup of
   the empty database may already be the latest pair.

## Changing things
- **Code or Moodle version:** raise `VERSION` in `build.sh` and the image
  tags in both compose files, then build. Put Moodle in maintenance mode,
  deploy, and wait for `moodle-setup: ready` in the cron log, because `cron`
  upgrades the database when it starts. Then purge the caches and leave
  maintenance mode.
- **Web replicas:** change `replicas` under `moodle` and deploy.
- **Database password:** change it inside MariaDB first, because MariaDB
  reads the secret only when it creates the database. Then write the new
  file, raise `_v1` to `_v2` in `production.yml` and deploy.
- **Admin password:** the secret only counts at the first install. Change it
  in Moodle afterwards.