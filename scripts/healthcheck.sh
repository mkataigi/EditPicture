#!/usr/bin/env bash
set -Eeuo pipefail

# Exit codes: 0 healthy, 1 not running/unreachable, 2 HTTP or API response abnormal.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="${REPO_ROOT}/run/comfyui.pid"
# shellcheck source=scripts/lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
load_editpicture_config "${REPO_ROOT}"
normalize_comfyui_port || {
  printf '[healthcheck] API ERROR: COMFYUI_PORT must be a decimal integer from 1 through 65535\n' >&2
  exit 2
}

body_file="$(mktemp "${TMPDIR:-/tmp}/editpicture-health.XXXXXX")"
trap 'rm -f -- "${body_file}"' EXIT
url_host="${COMFYUI_HOST}"
[[ "${url_host}" == *:* ]] && url_host="[${url_host}]"
url="http://${url_host}:${COMFYUI_PORT}/system_stats"

http_code="$(curl --silent --show-error --max-time 5 --output "${body_file}" --write-out '%{http_code}' "${url}" 2>/dev/null)" || {
  printf '[healthcheck] NOT RUNNING: cannot connect to %s\n' "${url}" >&2
  exit 1
}

if [[ ! "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
  printf '[healthcheck] API ERROR: %s returned HTTP %s\n' "${url}" "${http_code}" >&2
  exit 2
fi
valid_api=false
if command -v python3 >/dev/null 2>&1; then
  if python3 - "${body_file}" 2>/dev/null <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    value = json.load(stream)
if not isinstance(value, dict) or not ({"system", "devices"} & value.keys()):
    raise SystemExit(1)
PY
  then
    valid_api=true
  fi
elif grep -Eq '"(system|devices)"[[:space:]]*:' "${body_file}"; then
  valid_api=true
fi
if [[ "${valid_api}" != true ]]; then
  printf '[healthcheck] API ERROR: %s returned an unexpected response\n' "${url}" >&2
  exit 2
fi

pid_note="not managed by this checkout"
if [[ -f "${PID_FILE}" ]]; then
  pid="$(tr -cd '0-9' <"${PID_FILE}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    pid_note="managed PID ${pid}"
  else
    pid_note="healthy API with stale PID file"
  fi
fi
printf '[healthcheck] HEALTHY: %s (%s)\n' "${url}" "${pid_note}"
