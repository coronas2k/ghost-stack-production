#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
stack_cd_root
require_dotenv
load_env .env
: "${DOMAIN:?DOMAIN must be set in .env}"

HTTPS_PORT="${HTTPS_PORT:-443}"
BASE="https://${DOMAIN}"
if [[ "${HTTPS_PORT}" != "443" ]]; then
	BASE="${BASE}:${HTTPS_PORT}"
fi

CURL=(curl -fsS -k --connect-timeout 5 --max-time 30)

echo "== ${BASE}/ =="
"${CURL[@]}" -o /dev/null -w "HTTP %{http_code}\n" "${BASE}/"

echo "== ${BASE}/ghost/ =="
"${CURL[@]}" -o /dev/null -w "HTTP %{http_code}\n" "${BASE}/ghost/"

ASSET_PATH=$("${CURL[@]}" "${BASE}/" | sed -n 's/.*href="\(\/assets\/built\/screen\.css[^"]*\)".*/\1/p' | head -1)
if [[ -n "${ASSET_PATH}" ]]; then
	echo "== ${BASE}${ASSET_PATH} =="
	"${CURL[@]}" -o /dev/null -w "HTTP %{http_code}\n" "${BASE}${ASSET_PATH}"
else
	echo "WARN: no theme CSS link on homepage" >&2
fi

echo "OK"
