# Shared helpers for stack scripts. Source from scripts/; do not execute directly.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_ROOT="$(cd "$_lib_dir/.." && pwd)"

COMPOSE_PROD=(docker compose -f compose.yml)
COMPOSE_LOCAL=(docker compose -f compose.yml -f compose.local.yml)

stack_cd_root() {
	cd "$STACK_ROOT"
}

require_dotenv() {
	if [[ ! -f .env ]]; then
		echo "Missing .env — copy .env.example" >&2
		exit 1
	fi
}

load_env() {
	local env_file="${1:-.env}"
	# shellcheck disable=SC1090
	source "$env_file"
}

ensure_local_override_files() {
	[[ -f compose.local.yml ]] || cp compose.local.yml.example compose.local.yml
	[[ -f caddy/Caddyfile.local ]] || cp caddy/Caddyfile.local.example caddy/Caddyfile.local
}

compose_config_prod() {
	echo "== compose config =="
	"${COMPOSE_PROD[@]}" config >/dev/null
}

compose_config_local_if_present() {
	if [[ -f compose.local.yml ]] && [[ -f caddy/Caddyfile.local ]]; then
		echo "== local override config =="
		"${COMPOSE_LOCAL[@]}" config >/dev/null
	fi
}

assert_production_caddyfile() {
	if grep -q 'tls internal' caddy/Caddyfile; then
		echo "ERROR: production caddy/Caddyfile must not use 'tls internal'" >&2
		exit 1
	fi

	if ! grep -q 'email {$ACME_EMAIL}' caddy/Caddyfile; then
		echo "ERROR: production caddy/Caddyfile must set ACME email in the global options block" >&2
		exit 1
	fi

	if ! grep -q 'admin off' caddy/Caddyfile; then
		echo "WARN: consider 'admin off' in production Caddyfile global block" >&2
	fi
}

require_env_keys() {
	: "${DOMAIN:?DOMAIN must be set}"
	: "${DATABASE_PASSWORD:?DATABASE_PASSWORD must be set}"
	: "${DATABASE_ROOT_PASSWORD:?DATABASE_ROOT_PASSWORD must be set}"
	: "${ACME_EMAIL:?ACME_EMAIL must be set for production Caddy and Lets Encrypt}"
}
