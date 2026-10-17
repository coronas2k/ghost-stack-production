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

compose_config_prod

echo "== required env keys =="
load_env "$ENV_FILE"
require_env_keys

assert_production_caddyfile
compose_config_local_if_present

echo "OK"
