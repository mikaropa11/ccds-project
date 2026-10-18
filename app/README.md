# app stack: ratings monitor

`auto` reads the rating that web pages publish as schema.org JSON-LD
(`aggregateRating`) and posts it to `core`. `core` stores it in PostgreSQL,
caches the summary in Redis and shows it at https://app.ccds-project.duckdns.org.
It can also email a report through the `smtp` relay.

| Service | Image                  | Replicas | Role                                          |
|---------|------------------------|----------|-----------------------------------------------|
| core    | `app-core` (Flask)     | 2        | web page and API                              |
| static  | `app-static` (httpd)   | 2        | `/static/*`                                   |
| db      | `app-db` (postgres 17) | 1        | data in `/srv/nfs/app/db`                     |
| redis   | redis:8.2-alpine       | 1        | 30 s cache of the summary, no persistence     |
| smtp    | `app-smtp` (msmtpd)    | 2        | relays mail to a provider on 587              |
| backup  | `app-backup` (crond)   | 1        | nightly `pg_dump` to `/srv/nfs/app/backups`   |
| auto    | `app-auto` (python)    | 2        | each replica reads its share of the URLs      |

Stateless services have 2 replicas. `db` and `redis` have one because they hold
state (a DBMS and the shared cache), and `backup` because it is a cron job.

## Local
```sh
docker compose -f app/compose.yml up -d --build
```
- http://localhost:8080: the app. The `web` service stands in for the basic nginx.
- http://localhost:8025: mailpit, which catches the emails instead of a real provider.
- Report email: `curl -X POST -H 'X-Feed-Token: dev-token' localhost:8080/api/report`

## Production
### Secrets, once on the machine that deploys
`app/secrets/` is gitignored: the repository is public. The SMTP password is a
Gmail app password of the project account, typed without echo.
```sh
mkdir -p app/secrets
openssl rand -hex 24 | tr -d '\n' > app/secrets/db_password
openssl rand -hex 32 | tr -d '\n' > app/secrets/feed_token
read -rs P && printf '%s' "$P" | tr -d ' ' > app/secrets/smtp_password; unset P
cp app/smtp.env.example app/secrets/smtp.env   # and edit it
```

### Build and deploy
```sh
sudo docker login ccds-project.duckdns.org
sudo app/build.sh
sudo docker stack deploy --with-registry-auth -c app/production.yml app
```

### Data on NFS
Swarm refuses a bind mount whose source dir does not exist, so `db` and
`backup` mount the whole share (`/srv/nfs` → `/nfs`) and create
`/srv/nfs/app/db` and `/srv/nfs/app/backups` on start, owned by `postgres`
(uid 70, see `db/nfs-dir.sh`). The price is that these two containers see the
whole share.

This needs root in the containers to write to the share, so the export on
swarm-manager-1 uses `no_root_squash` (only for the cluster subnet):
```
/srv/nfs 10.0.1.0/24(rw,sync,fsid=0,no_subtree_check,no_root_squash)
```
With `root_squash`, root becomes `nobody` on manager-2 and manager-3 and cannot
create the dirs. The registry had the same problem.

### nginx (basic stack)
`basic/nginx/default.conf` routes `app.ccds-project.duckdns.org`:
`/static/` to `app-static:80`, the rest to `app-core:8000`, and `/metrics`
answers 404. The certificate covers `app.` (`basic/certbot`).

## Backups
- `backup` runs `pg_dump --format=custom` every day at 03:00 and keeps 7 days.
  Each dump is checked with `pg_restore --list` before it is kept.
- Manual backup and restore, on the node that runs the task:
  ```sh
  c=$(sudo docker ps -q -f name=app_backup)
  sudo docker exec $c gosu postgres backup.sh
  sudo docker exec $c restore.sh                # latest dump
  sudo docker exec $c restore.sh app-20261019-030000.dump
  ```
- Redis has no backup: it only holds a 30 s cache.

## Changing things
- **Code:** raise `VERSION` in `build.sh` and the tags in `production.yml`, then build and deploy.
- **Feeder replicas:** change `deploy.replicas` and `FEEDER_REPLICAS` together.
- **A secret:** write the new file, raise its `_v1` → `_v2` in `production.yml`, then deploy.
