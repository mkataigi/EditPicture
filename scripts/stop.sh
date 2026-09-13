#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PID_FILE="${REPO_ROOT}/run/comfyui.pid"
# shellcheck source=scripts/lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=scripts/lib/comfy-cli.sh
source "${SCRIPT_DIR}/lib/comfy-cli.sh"
load_editpicture_config "${REPO_ROOT}"

fail() { printf '[stop] ERROR: %s\n' "$*" >&2; exit 1; }

if [[ ! -f "${PID_FILE}" ]]; then
  printf '[stop] No managed ComfyUI PID file; nothing to stop.\n'
  exit 0
fi
normalize_comfyui_port || fail "COMFYUI_PORT must be a decimal integer from 1 through 65535"
cli_error="$(check_comfy_cli 2>&1)" || fail "${cli_error}; run ./scripts/setup.sh"
saved_pid="$(tr -cd '0-9' <"${PID_FILE}")"
[[ "${saved_pid}" =~ ^[1-9][0-9]*$ ]] || fail "Invalid PID file: ${PID_FILE}"
if ! kill -0 "${saved_pid}" 2>/dev/null; then
  rm -f -- "${PID_FILE}"
  printf '[stop] Removed stale PID file for PID %s; process was not running.\n' "${saved_pid}"
  exit 0
fi

response_file="$(mktemp "${TMPDIR:-/tmp}/editpicture-comfy-stop.XXXXXX")"
trap 'rm -f -- "${response_file}"' EXIT
if ! comfy --json --workspace="${COMFYUI_WORKSPACE}" stop --port "${COMFYUI_PORT}" --dry-run >"${response_file}" 2>&1; then
  sed -n '1,120p' "${response_file}" >&2
  fail "Could not identify the ComfyUI process through comfy-cli; no process was stopped"
fi

reported_pid="$(extract_pid "${response_file}" || true)"
[[ "${reported_pid}" =~ ^[1-9][0-9]*$ ]] || fail "Dry-run returned no PID; no process was stopped"
[[ "${reported_pid}" == "${saved_pid}" ]] || \
  fail "PID mismatch (managed=${saved_pid}, comfy-cli=${reported_pid}); no process was stopped"

comfy --json --workspace="${COMFYUI_WORKSPACE}" stop --port "${COMFYUI_PORT}"
rm -f -- "${PID_FILE}"
printf '[stop] Stopped managed ComfyUI process %s.\n' "${saved_pid}"
