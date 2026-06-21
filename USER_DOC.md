# User Documentation

This document explains how to use the Inception stack as an end user or administrator: what it provides, how to start/stop it, how to access the site and the admin panel, where credentials live, and how to verify everything is running correctly.

## What this stack provides

Inception runs a complete WordPress website, split across three containers:

- **nginx** — the only entry point, serving the site over HTTPS (port 443).
- **wordpress** — the WordPress application itself (blog, pages, admin panel).
- **mariadb** — the database storing all WordPress content (posts, users, settings).

From the outside, this all behaves like a single website reachable at `https://noakebli.42.fr`.

## Starting and stopping the stack

All commands are run from the root of the repository.

**Start everything** (builds the images on first run, then starts the containers):
```bash
make
```
Wait until the logs settle and `nginx`, `wordpress`, and `mariadb` all report as running — the first start takes longer since WordPress is being installed.

**Stop the stack** (containers are stopped, data is kept):
```bash
make down
```

**Stop and wipe the data** (containers and Docker volumes are removed — irreversible):
```bash
make clean
```

**Full reset** (also removes the local data directory and unused Docker resources):
```bash
make fclean
```

**Rebuild from scratch**:
```bash
make re
```

## Accessing the website and the admin panel

1. Make sure `noakebli.42.fr` resolves to your machine — on Linux, add this line to `/etc/hosts`:
   ```
   127.0.0.1   noakebli.42.fr
   ```
2. Open `https://noakebli.42.fr` in a browser. Since the TLS certificate is self-signed (generated locally for the project, not issued by a public certificate authority), the browser will show a security warning — this is expected; accept/continue to reach the site.
3. To access the WordPress administration panel, go to `https://noakebli.42.fr/wp-admin` and log in with one of the accounts described below.

## Locating and managing credentials

All credentials are stored in a single configuration file: `srcs/.env`, at the root of the `srcs` folder.

| Variable           | Purpose                                              |
|---------------------|-------------------------------------------------------|
| `DOMAIN_NAME`        | The site's domain name (used in URLs and the TLS cert) |
| `MYSQL_DATABASE`     | Name of the WordPress database                        |
| `MYSQL_USER` / `MYSQL_PASSWORD` | Application database account used by WordPress |
| `MYSQL_ROOT_PASSWORD`| MariaDB root account password                          |
| `WP_ADMIN` / `WP_ADMIN_PASS` / `WP_ADMIN_EMAIL` | WordPress administrator account |
| `WP_USER` / `WP_USER_PASS` / `WP_USER_EMAIL`   | Secondary WordPress account (author role) |

To change a password or account, edit the corresponding value in `srcs/.env` **before** the first `make` run (the database and WordPress accounts are only created once, on first initialization). To apply a credential change after the stack has already been initialized, you need to wipe existing data first:
```bash
make fclean
make
```

⚠️ `srcs/.env` contains plaintext secrets — never commit it to a public repository or share it outside the project.

## Checking that services are running correctly

**Check container status:**
```bash
docker compose -f srcs/docker-compose.yml ps
```
All three services (`nginx`, `wordpress`, `mariadb`) should show as `Up`/`running`.

**Check the logs of a specific service** (useful if something looks wrong):
```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

**Quick health checks:**
- `https://noakebli.42.fr` loads the WordPress homepage → nginx, php-fpm, and the database are all working together.
- `https://noakebli.42.fr/wp-admin` shows a login form → WordPress is correctly configured and connected to the database.
- `docker ps` shows all three containers with status `Up` and no repeated restarts → no container is crash-looping.

If a container keeps restarting, check its logs first (see above) — most issues come from a misconfigured `.env` value or stale data from a previous run (in which case `make fclean && make` resolves it).