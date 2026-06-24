*This project has been created as part of the 42 curriculum by noakebli.*

# Inception

## Description

**Inception** is a 42 systems administration project whose goal is to learn how to build, orchestrate, and secure a small multi-service infrastructure using **Docker** and **Docker Compose**, with every image built **from scratch** (no pulling pre-built images like `nginx:latest` or `wordpress:latest`).

The deliverable is a working WordPress website, served over HTTPS, where each functional component — web server, application server, database — lives in its own container, communicates over a private network, and persists its data outside the container lifecycle.

### Project architecture

The stack is made of three custom-built Debian-based images, one per service, orchestrated with `docker-compose.yml`:

```
                         ┌────────────────────────┐
   :443 (HTTPS) ───────► │         NGINX            │
                         │   (TLS 1.2 / 1.3)        │
                         └───────────┬─────────────┘
                                     │ fastcgi :9000
                         ┌───────────▼─────────────┐
                         │       WordPress           │
                         │   (php-fpm 8.2 + WP-CLI)  │
                         └───────────┬─────────────┘
                                     │ :3306
                         ┌───────────▼─────────────┐
                         │        MariaDB            │
                         └──────────────────────────┘

         "inception" bridge network (internal DNS by service name)
```

| Service       | Role                                      | Base image        |
|---------------|--------------------------------------------|---------------------|
| **nginx**     | Single HTTPS entry point / reverse proxy   | `debian:bullseye`  |
| **wordpress** | WordPress CMS, run through php-fpm         | `debian:bullseye`  |
| **mariadb**   | WordPress database                         | `debian:bullseye`  |

Only `nginx` publishes a port to the host (443). WordPress and MariaDB are reachable solely through the internal Docker network, which keeps the application and database layers out of reach from the outside.

Each container's entrypoint script (`init.sh`) handles first-run initialization (certificate generation, WordPress install via WP-CLI, database/user creation) and then `exec`s the real service process in the foreground, so the container's lifecycle is tied to that process — no artificial `tail -f /dev/null` or infinite sleep loops.

### Main design choices

- **One service per container**, each with its own Dockerfile, so each piece can be rebuilt, scaled, or replaced independently.
- **Custom bridge network** (`inception`) so containers resolve each other by service name instead of hard-coded IPs.
- **Self-signed TLS certificate** generated at container startup (via `openssl`) rather than baked into the image, restricted to TLSv1.2/TLSv1.3.
- **Configuration centralized in `.env`**, injected into every container through `env_file`, so credentials are never hard-coded in Dockerfiles or source.
- **Idempotent entrypoints**: each `init.sh` checks whether initialization already happened (existing WordPress install, existing database directory) before re-running setup, so containers can restart without re-installing everything.
- **Data persistence outside the container lifecycle**, using bind-mounted volumes pinned to fixed paths on the host (see below).

### Virtual Machines vs Docker

A **Virtual Machine** virtualizes an entire computer: a hypervisor emulates hardware and each VM runs its own full OS kernel on top of it. This gives very strong isolation but is heavy — each VM has its own kernel, its own memory footprint, slow boot times, and significant disk usage.

A **Docker container** shares the host's kernel and uses Linux namespaces and cgroups to isolate processes, network, and filesystem. Containers start in milliseconds, share base image layers, and use far less RAM/disk than a VM, at the cost of weaker isolation (a kernel-level vulnerability can in theory affect every container on the host).

This project uses Docker because the goal is to run several lightweight, independent services on a single host with fast iteration during development, not to fully isolate untrusted multi-tenant workloads — process-level isolation is sufficient for an nginx/WordPress/MariaDB stack.

### Secrets vs Environment Variables

This project passes credentials through **environment variables**, declared in `srcs/.env` and injected into every container with `env_file: .env` in `docker-compose.yml`. This is simple to set up and works well for a school project: WP-CLI and the MariaDB init script read these variables directly.

The trade-off is that environment variables are visible to anything that can inspect the container: `docker inspect`, `docker exec <container> env`, or reading `/proc/<pid>/environ`. They also end up in shell history or CI logs if not handled carefully.

A **secrets manager** (Docker Swarm/Kubernetes secrets, HashiCorp Vault, etc.) instead mounts sensitive values as files inside the container (typically under `/run/secrets/`), encrypted at rest, with access restricted at the orchestrator level, and supports rotation without rebuilding the image. For a production deployment, secrets would be the safer choice; for this project's scope, `.env` (kept out of version control via `.gitignore`) was considered an acceptable trade-off.

### Docker Network vs Host Network

With the **host network** driver, a container shares the host's network namespace directly: no port mapping is needed, but the container also has unrestricted access to every interface and port on the host, and there is no internal DNS or network isolation between containers.

This project instead defines a dedicated **bridge network** (`inception`). Each container gets its own private IP on that network, Docker provides automatic DNS resolution by service name (e.g. `wordpress` resolves to the WordPress container's IP), and only the port explicitly published in `docker-compose.yml` (443, on `nginx`) is reachable from outside. MariaDB's 3306 and php-fpm's 9000 stay strictly internal, which is the correct security posture for a stack where only one service should be publicly exposed.

### Docker Volumes vs Bind Mounts

A **named Docker volume** is created and managed entirely by the Docker daemon, stored under `/var/lib/docker/volumes/...`, decoupled from any specific host directory structure. It's portable across hosts and easy to back up with `docker volume` commands, but you don't directly control where on disk the data physically lives.

A **bind mount** maps an explicit host path directly into the container. You control exactly where the data is stored, but the setup is tied to that specific host's filesystem layout.

This project actually combines both: `docker-compose.yml` declares named volumes (`mariadb_data`, `wordpress_data`) so they appear in `docker volume ls` and are referenced like normal volumes in the service definitions, but each one is configured with `driver_opts: { type: none, o: bind, device: /home/noakebli/data/... }`. This makes them **named volumes backed by a bind mount**: the subject requires data to live at a predictable path under the user's home directory, while still benefiting from the named-volume syntax in Compose.

## Instructions

### Prerequisites

- Docker Engine and Docker Compose v2 (`docker compose`, not the legacy `docker-compose`).
- `make`.
- A Linux environment with root/sudo access (required by the 42 Docker subject — typically a personal VM on campus).
- Port 443 free on the host.

### Setup

1. Clone the repository and move into it:
   ```bash
   git clone git@github.com:noraake/Inception.git
   cd Inception
   ```
2. Add the project domain to `/etc/hosts` so it resolves to your machine:
   ```
   127.0.0.1   noakebli.42.fr
   ```
3. Review/adjust `srcs/.env` (database name, users, passwords, WordPress admin/author accounts) and `DATA_PATH` in the `Makefile` if your login differs.

### Build & run

```bash
make
```

This creates the data directories under `DATA_PATH` and runs `docker compose up --build`, building all three images and starting the stack.

Once the containers are up, the site is reachable at `https://noakebli.42.fr`. Since the certificate is self-signed, the browser will show a security warning that needs to be accepted manually.

### Other Makefile targets

| Command       | Action                                                              |
|---------------|------------------------------------------------------------------------|
| `make down`   | Stops the containers without touching volumes                         |
| `make clean`  | Stops the containers and removes the Docker volumes                   |
| `make fclean` | `clean` + `docker system prune -f` + removal of `DATA_PATH` on disk  |
| `make re`     | `fclean` then `make` (full rebuild from a clean state)                |

See `USER_DOC.md` and `DEV_DOC.md` for more detailed usage and development instructions.

## Resources

### Documentation & references

- [Docker official documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [NGINX FastCGI module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [WP-CLI documentation](https://wp-cli.org/)
- [WordPress Codex / Developer resources](https://developer.wordpress.org/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- [OpenSSL `req` man page](https://docs.openssl.org/master/man1/openssl-req/) (self-signed certificate generation)
- 42 "Inception" subject PDF (internal resource)

### AI usage

AI (Claude, by Anthropic) was used as a learning and debugging aid during this project, not to generate the infrastructure unsupervised. Specifically:

- **Debugging**: diagnosing a MariaDB "host connection" error traced back to a flawed conditional in `mariadb/tools/init.sh` combined with stale Docker volumes from a previous run.
- **Concept explanations**: clarifying Docker networking (bridge driver, custom networks, internal DNS resolution) and volume mechanics (named volumes vs. bind mounts), which directly informed the design choices described above.
- **Documentation**: drafting and structuring this `README.md`, `USER_DOC.md`, and `DEV_DOC.md` based on the project's actual source files, then reviewed and adjusted by the student.

All Dockerfiles, configuration files, and entrypoint scripts were written and tested by the student; AI assistance was limited to explanation, debugging guidance, and documentation drafting.
