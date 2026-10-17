# Ghost production stack (Docker)

[Ghost 6](https://ghost.org/docs/install/docker/) with **Caddy** (TLS and reverse proxy) and **MySQL 8**.

Operations use `./scripts/stack.sh` (see `./scripts/stack.sh help`).

## Quick start

1. Copy configuration and set secrets:

   ```bash
   cp .env.example .env
   # Edit .env: DOMAIN, ACME_EMAIL, DATABASE_ROOT_PASSWORD, DATABASE_PASSWORD, mail__*
   ```

2. Start the stack:

   ```bash
   ./scripts/stack.sh up
   ```

3. Open `https://YOUR_DOMAIN/ghost/` and complete Ghost setup.

Do not change `DATABASE_*` values in `.env` after MySQL has initialized the data directory.

## Let's Encrypt (production TLS)

Caddy obtains and renews certificates automatically when you run `./scripts/stack.sh up` with a **public** `DOMAIN`.

1. Point DNS **A** (and **AAAA** if you use IPv6) at the server running this stack.
2. Allow inbound **TCP 80** and **443** (port 80 is required for ACME HTTP-01 validation and HTTP→HTTPS redirects).
3. Set `ACME_EMAIL` in `.env` (see `.env.example`). Use a real address; the CA may send expiry notices (renewal is still automatic if Caddy is healthy).
4. Optional: set `ACME_CA` to the [Let's Encrypt staging](https://letsencrypt.org/docs/staging-environment/) directory while testing issuance, then switch to the production URL before go-live.
5. Keep the `caddy_data` volume intact; it stores issued keys and certificates. Do not wipe it during routine upgrades.

Check issuance: `./scripts/stack.sh logs` (Caddy logs ACME activity) or `docker compose exec caddy caddy list-certificates` if you need details.

Validate before deploy:

```bash
./scripts/stack.sh validate
./scripts/stack.sh local-up   # local HTTPS; or stack.sh up for production TLS
./scripts/stack.sh smoke      # after containers are healthy
```

## Commands

| Task | Command |
| --- | --- |
| Validate compose + env | `./scripts/stack.sh validate` |
| Production start | `./scripts/stack.sh up` |
| Local HTTPS (OrbStack / internal TLS) | `./scripts/stack.sh local-up` |
| HTTP smoke test (stack running) | `./scripts/stack.sh smoke` |
| Stop | `./scripts/stack.sh down` / `./scripts/stack.sh local-down` |
| Logs | `./scripts/stack.sh logs` |
| After `DOMAIN` change | `./scripts/stack.sh recreate-front` |

Requires `.env` from `.env.example`. Local override: `compose.local.yml` and `caddy/Caddyfile.local` (created by `local-up` when missing).

## Local HTTPS (OrbStack or internal CA)

Set `DOMAIN` in `.env` to your Caddy hostname (see comment in `.env.example` for OrbStack).

```bash
./scripts/stack.sh local-up
```

This copies `compose.local.yml.example` → `compose.local.yml` and `caddy/Caddyfile.local.example` → `caddy/Caddyfile.local` when those files are missing. Production `caddy/Caddyfile` uses public automatic HTTPS only (no `tls internal`).

After changing `DOMAIN`:

```bash
./scripts/stack.sh recreate-front
```

## Layout

| Path | Purpose |
| --- | --- |
| `compose.yml` | Caddy, Ghost, MySQL 8 |
| `caddy/Caddyfile` | Production reverse proxy |
| `.env` | Secrets and domain (not committed) |
| `scripts/` | `stack.sh`, `validate.sh`, `smoke.sh` |
| `.github/workflows/` | Compose config CI check |
| `data/ghost` | Ghost content volume |
| `data/mysql` | MySQL data volume |

CI runs `./scripts/validate.sh` with a fixture env on push and pull request (`.github/workflows/compose-validate.yml`).
