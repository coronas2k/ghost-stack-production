# Ghost production stack (Docker)

[Ghost 6](https://ghost.org/docs/install/docker/) with **Caddy** (TLS and reverse proxy) and **MySQL 8**.

Operations use `./scripts/stack.sh` (see `./scripts/stack.sh help`).

## Why use this

This repo is a **small, opinionated Compose stack** for running your own Ghost site on a VPS or dedicated host—not a managed platform and not a theme or content repo. It gives you a path from `cp .env.example .env` to HTTPS without hand-rolling nginx configs, certbot timers, or unpinned `latest` images.

**Good fit if you want:**

- Self-hosted publishing with full control over data (MySQL + Ghost content on your volumes).
- **Automatic TLS** and renewals via Caddy and Let's Encrypt, with secrets kept in `.env` instead of the image or git.
- A **single edge** (Caddy) and **no MySQL port on the host**—only HTTP/HTTPS are published.
- **Repeatable checks** before deploy (`validate`, `smoke`) and CI that catches broken compose or production Caddy misconfig early.

**Not a substitute for:** backups, monitoring, WAF, or Ghost Admin membership policy—you still configure SMTP, DNS, firewall, and Ghost settings for your threat model.

## Benefits

| Area | What you get |
| --- | --- |
| **TLS** | Let's Encrypt issuance and renewal; HTTP→HTTPS redirect; cert state in `caddy_data` volume |
| **Proxy** | All traffic through Caddy to Ghost; correct `Host` / `X-Forwarded-*` for Ghost's public `url` |
| **Data** | MySQL 8 (utf8mb4); persistent `data/mysql` and `data/ghost` bind mounts |
| **Supply chain** | Digest-pinned Caddy and MySQL images; explicit Ghost version tag |
| **Operations** | `stack.sh` for up/down/local HTTPS/logs; healthchecks so Caddy starts after Ghost is ready |
| **Local dev** | Optional `local-up` with internal TLS (OrbStack-friendly) without changing production `Caddyfile` |

## Security and hardening

Production `caddy/Caddyfile` is written for a **public internet** edge:

- **Caddy admin API disabled** (`admin off`) so the container does not expose a config control plane.
- **Response headers:** HSTS (production site block), `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`, `Permissions-Policy`; `Server` stripped at the proxy.
- **Compression** at the edge (`zstd` + `gzip`); Ghost runs with `compress: n` so work is not duplicated.
- **TLS automation** via ACME (`ACME_EMAIL`, `ACME_CA`); production file must not use `tls internal` (enforced by `validate.sh`).
- **Network exposure:** MySQL is `expose` only on the Compose network; Ghost is not published to the host—only Caddy binds **80/443**.
- **Secrets:** `.env` is gitignored; compose fails fast if `DOMAIN`, database passwords, or `ACME_EMAIL` are missing.
- **Logging:** json-file driver with size/file rotation on all services.

Ghost still sets some application headers (for example `X-Powered-By`); tighten membership signup and staff security in **Ghost Admin** after setup.

## Production readiness

What “production ready” means **here**:

1. **Pinned, health-checked services** — `db`, `ghost`, and `caddy` must pass healthchecks; Caddy waits for a healthy Ghost before serving.
2. **Production vs local split** — Production uses public automatic HTTPS; local override swaps in `Caddyfile.local` + `compose.local.yml` without baking dev TLS into the production proxy config.
3. **Config guardrails** — `scripts/validate.sh` checks required env keys, renders compose, rejects internal TLS in production Caddyfile, and validates local overrides when present.
4. **Smoke path** — `scripts/smoke.sh` hits `/`, `/ghost/`, and theme CSS over HTTPS (after you trust your CA locally or use a real cert).
5. **CI** — GitHub Actions runs the same validate path on every push/PR so compose and Caddy rules do not regress silently.

**You are still responsible for:** DNS pointing at the host, firewall rules, strong `.env` passwords, production SMTP, backups of `data/`, OS and image updates, and completing Ghost setup (owner account, URL, membership access). Run `./scripts/stack.sh validate` before every production deploy.

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
