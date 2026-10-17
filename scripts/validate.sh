#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
stack_cd_root

ENV_FILE="${1:-.env}"
if [[ ! -f "$ENV_FILE" ]]; then
	echo "Missing ${ENV_FILE} — copy .env.example to .env" >&2
	exit 1
fi

# compose.yml ghost service uses env_file: .env
if [[ ! -f .env ]]; then
	cp "$ENV_FILE" .env
fi

echo "== required env keys =="
load_env "$ENV_FILE"
require_env_keys

compose_config_prod

assert_production_caddyfile
compose_config_local_if_present

echo "OK"
