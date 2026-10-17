#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
stack_cd_root

usage() {
	cat <<'EOF'
Usage: ./scripts/stack.sh <command>

  config          Render production compose config
  up              Pull and start production stack
  down            Stop production stack
  local-up        Create local override files if needed; start with internal TLS
  local-down      Stop stack using local compose override
  logs            Follow production service logs
  ps              Production service status
  recreate-front  Recreate ghost and caddy (after DOMAIN change)
  validate        Validate compose and env file (default: .env)
  smoke           HTTP smoke test (stack must be running; uses .env)

EOF
	exit "${1:-0}"
}

[[ $# -ge 1 ]] || usage 1

case "$1" in
config)
	"${COMPOSE_PROD[@]}" config
	;;
up)
	"${COMPOSE_PROD[@]}" pull
	"${COMPOSE_PROD[@]}" up -d
	;;
down)
	"${COMPOSE_PROD[@]}" down
	;;
local-up)
	ensure_local_override_files
	"${COMPOSE_LOCAL[@]}" pull
	"${COMPOSE_LOCAL[@]}" up -d
	;;
local-down)
	"${COMPOSE_LOCAL[@]}" down
	;;
logs)
	"${COMPOSE_PROD[@]}" logs -f --tail=100
	;;
ps)
	"${COMPOSE_PROD[@]}" ps
	;;
recreate-front)
	"${COMPOSE_PROD[@]}" up -d --force-recreate ghost caddy
	;;
validate)
	exec "$SCRIPT_DIR/validate.sh" "${2:-.env}"
	;;
smoke)
	require_dotenv
	exec "$SCRIPT_DIR/smoke.sh"
	;;
-h | --help | help)
	usage
	;;
*)
	echo "Unknown command: $1" >&2
	usage 1
	;;
esac
