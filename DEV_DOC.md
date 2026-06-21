# Developer Documentation

This document describes how to set up, build, and operate the Inception stack from a developer's point of view: environment setup, build/launch process, container/volume management commands, and data persistence.

## Setting up the environment from scratch

### Prerequisites

- A Linux host (the project targets Debian/Ubuntu-style environments; on the 42 campus this is typically a personal VM).
- Docker Engine and the Docker Compose v2 plugin (`docker compose`, invoked as a subcommand, not the standalone `docker-compose` binary).
- `make`.
- `sudo` rights (used by `make fclean` to remove the data directory, and generally required to run Docker on the campus setup).

### Repository layout

```
inception/
├── Makefile
└── srcs/
    ├── .env                      # all credentials / config, injected via env_file
    ├── docker-compose.yml        # service, network, and volume definitions
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf   # HTTPS server block, FastCGI passthrough to wordpress:9000
        │   └── tools/init.sh     # generates the self-signed cert, then execs nginx
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf     # php-fpm pool config
        │   └── tools/init.sh     # waits for mariadb, installs WP via WP-CLI, execs php-fpm
        └── mariadb/
            ├── Dockerfile
            ├── conf/my.conf      # mariadbd config (datadir, bind-address)
            └── tools/init.sh     # initializes datadir, creates DB/user, execs mysqld
```

### Configuration / secrets

1. Copy or edit `srcs/.env` with the values you want for this environment (domain, database name/user/password, WordPress admin and secondary user). All three services read this same file via `env_file: .env` in `docker-compose.yml`.
2. Update `DATA_PATH` in the `Makefile` (top of the file) to match your home directory/login if different from the default — this is where persistent data will be bind-mounted on the host.
3. Add the chosen `DOMAIN_NAME` to `/etc/hosts` pointing at `127.0.0.1` so the TLS certificate's CN matches the URL you browse to.

`.env` should never be committed to version control — add it to `.gitignore` if it isn't already.

## Building and launching

The project is driven through the `Makefile`, which wraps `docker compose` calls (see `srcs/docker-compose.yml`):

```bash
make          # mkdir -p $(DATA_PATH)/{mariadb,wordpress} && docker compose ... up --build
```

This builds all three images (`nginx`, `wordpress`, `mariadb`) from their respective Dockerfiles under `srcs/requirements/` and starts the containers attached to the `inception` bridge network.

You can also drive Compose directly for finer control during development:

```bash
# Build images without starting containers
docker compose -f srcs/docker-compose.yml --env-file srcs/.env build

# Start in detached mode
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d

# Rebuild a single service after editing its Dockerfile/config
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build wordpress
```

## Managing containers and volumes

**Container lifecycle:**
```bash
docker compose -f srcs/docker-compose.yml ps              # status of all services
docker compose -f srcs/docker-compose.yml logs -f nginx    # follow logs for one service
docker compose -f srcs/docker-compose.yml restart wordpress
docker compose -f srcs/docker-compose.yml exec wordpress bash   # shell into a running container
```

**Stopping / cleaning, via Makefile:**
```bash
make down     # docker compose down            (containers removed, volumes kept)
make clean    # docker compose down -v         (containers + Docker volumes removed)
make fclean   # clean + docker system prune -f + rm -rf $(DATA_PATH)
make re       # fclean && make                 (full rebuild)
```

**Inspecting the network and volumes directly:**
```bash
docker network inspect inception_inception   # confirm containers share the bridge network
docker volume ls                              # mariadb_data / wordpress_data
docker volume inspect inception_mariadb_data  # confirm the bind-mount target path
```

## Data storage and persistence

`docker-compose.yml` declares two named volumes, `mariadb_data` and `wordpress_data`, but configures each with `driver_opts: { type: none, o: bind, device: ... }`, which binds them to fixed paths on the host rather than Docker's internal volume storage:

| Volume           | Host path                              | Mounted in container at |
|-------------------|------------------------------------------|----------------------------|
| `mariadb_data`     | `/home/noakebli/data/mariadb`           | `/var/lib/mysql` (mariadb) |
| `wordpress_data`   | `/home/noakebli/data/wordpress`         | `/var/www/html` (wordpress and nginx) |

Because of this, all WordPress files and the entire MariaDB database survive `make down` and even container/image rebuilds — the data lives on the host filesystem, independent of the containers' lifecycle. The only commands that delete this data are `make clean` (removes the Docker volume references) and `make fclean` (also `rm -rf`s the host directories themselves).

When debugging "the database/site looks reset", check first whether `$(DATA_PATH)` still contains the expected files (`ls -la /home/noakebli/data/mariadb` / `wordpress`) — an empty directory there means a previous `clean`/`fclean` wiped the data, not a bug in the entrypoint scripts.

### Note on entrypoint idempotency

Both `wordpress/tools/init.sh` and `mariadb/tools/init.sh` check for existing state before running first-time setup (`wp core is-installed` for WordPress, the presence of `/var/lib/mysql/${MYSQL_DATABASE}` for MariaDB). This means restarting an existing stack (`make down && make`) reuses the persisted data instead of reinitializing it — useful to know when debugging unexpected "already installed" or "database already exists" behavior versus a genuinely fresh setup.