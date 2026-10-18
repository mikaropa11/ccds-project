# ccds-project

## Registry login

The registry at `ccds-project.duckdns.org` only answers to team members.
Each teammate has one account, and the registry stores only bcrypt
hashes of the passwords.

### 1. Create your account line

Run this on your own machine and type a password when asked:

```bash
docker run --rm -it --entrypoint htpasswd httpd:2 -nB <your-name>
```

It prints one line, `<your-name>:$2y$05$...`. Send only that line to
whoever deploys. Never send the password itself.

### 2. The password file

On the machine that deploys, `basic/secrets/registry_htpasswd` holds
every teammate's line, one per line. Git ignores `basic/secrets/`, so
the file never reaches this public repository.

The file reaches the registry as the Swarm secret `registry_htpasswd_v1`.
Swarm secrets cannot change in place: when the file changes, raise the
version in `basic/compose.yml`, for example to `registry_htpasswd_v2`,
then deploy again.

### 3. Building, pushing and deploying

Log in once on the machine that builds and deploys:

```bash
docker login ccds-project.duckdns.org
```

Push images under a new version tag, the one `basic/compose.yml` uses:

```bash
docker build -t ccds-project.duckdns.org/nginx-proxy:1.5 basic/nginx
docker push ccds-project.duckdns.org/nginx-proxy:1.5
```

Always deploy with `--with-registry-auth`. The flag hands your login to
every node, so the nodes can pull images from the registry:

```bash
docker stack deploy --with-registry-auth -c basic/compose.yml basic
```

A deploy without the flag leaves the nodes unable to pull new images.
If you run Docker with `sudo`, use `sudo` for every command above, so
the login is stored for the same user that pushes and deploys.
