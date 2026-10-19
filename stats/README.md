# Stats

This directory contains the monitoring configuration for local development and production.

## Local environment

The local stack is defined in `compose.yml` and uses Docker Compose.

It runs Prometheus to collect metrics, Grafana to visualize them, Node Exporter to monitor the host, and cAdvisor to monitor containers.

- **Grafana:** `http://localhost:8080/grafana/`
- **Prometheus configuration:** `prometheus/prometheus.yml`
- **Grafana datasource:** `grafana/provisioning/datasources/prometheus.yml`

### Grafana password

Create `stats/.env` with a generated password:

```bash
cd stats
printf 'GRAFANA_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env
chmod 600 .env
```

Docker Compose reads this variable to configure the Grafana administrator password.

Start the local stack from the repository root:

```bash
docker compose -f stats/compose.yml up -d
```

## Production environment

The production stack is defined in `production.yml` and deployed to Docker Swarm.

Prometheus and Grafana run on `swarm-manager-1`. Node Exporter and cAdvisor monitor the three Swarm VMs.

- **Grafana:** `https://ccds-project.duckdns.org/grafana/`
- **Prometheus configuration:** `prometheus/prometheus-production.yml`
- **Grafana datasource:** `grafana/provisioning/datasources/prometheus.yml`

### Grafana password

Create the secret file at `stats/secrets/grafana_admin_password`:

```bash
cd stats
mkdir -p secrets
openssl rand -hex 24 > secrets/grafana_admin_password
chmod 600 secrets/grafana_admin_password
```

The production Compose file declares this file as the `grafana_admin_password` secret. Grafana reads it from `/run/secrets/grafana_admin_password` using `GF_SECURITY_ADMIN_PASSWORD__FILE`.

Deploy from the repository root:

```bash
docker stack deploy --with-registry-auth -c stats/production.yml monitoring
```

## Security

Do not commit `stats/.env`, `stats/secrets/grafana_admin_password`.
