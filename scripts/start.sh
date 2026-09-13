#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
MODEL_CONFIG="${REPO_ROOT}/comfy/config/extra_model_paths.yaml"
PID_FILE="${REPO_ROOT}/run/comfyui.pid"
LAUNCH_RESPONSE_FILE="${REPO_ROOT}/logs/comfy-cli-launch.json"
# shellcheck source=scripts/lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=scripts/lib/comfy-cli.sh
source "${SCRIPT_DIR}/lib/comfy-cli.sh"

load_editpicture_config "${REPO_ROOT}"

fail() { printf '[start] ERROR: %s\n' "$*" >&2; exit 1; }

normalize_comfyui_port || fail "COMFYUI_PORT must be a decimal integer from 1 through 65535"
[[ "${COMFYUI_HOST}" == "127.0.0.1" || "${COMFYUI_HOST}" == "localhost" || "${COMFYUI_HOST}" == "::1" ]] || \
  fail "Refusing non-local COMFYUI_HOST=${COMFYUI_HOST}. This project defaults to local-only access."
cli_error="$(check_comfy_cli 2>&1)" || fail "${cli_error}; run ./scripts/setup.sh"
for required in main.py folder_paths.py requirements.txt comfy; do
  [[ -e "${COMFYUI_WORKSPACE}/${required}" ]] || fail "ComfyUI is incomplete at ${COMFYUI_WORKSPACE} (missing ${required}); run ./scripts/setup.sh"
done
[[ -f "${MODEL_CONFIG}" ]] || fail "Model path config is missing; run ./scripts/setup.sh"
mkdir -p -- "${REPO_ROOT}/run" "${REPO_ROOT}/logs" "${REPO_ROOT}/input" "${REPO_ROOT}/output"

if [[ -f "${PID_FILE}" ]]; then
  existing_pid="$(tr -cd '0-9' <"${PID_FILE}")"
  if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
    probe_file="$(mktemp "${TMPDIR:-/tmp}/editpicture-comfy-probe.XXXXXX")"
    if comfy --json --workspace="${COMFYUI_WORKSPACE}" stop --port "${COMFYUI_PORT}" --dry-run >"${probe_file}" 2>&1; then
      reported_pid="$(extract_pid "${probe_file}" || true)"
      if [[ "${reported_pid}" == "${existing_pid}" ]]; then
        rm -f -- "${probe_file}"
        fail "Managed ComfyUI is already running with PID ${existing_pid}; use ./scripts/healthcheck.sh"
      fi
    fi
    rm -f -- "${probe_file}" "${PID_FILE}"
    if "${SCRIPT_DIR}/healthcheck.sh" >/dev/null 2>&1; then
      fail "Removed a stale PID file, but port ${COMFYUI_PORT} already serves a ComfyUI API; no second server was started"
    fi
    printf '[start] Removed stale PID file for unrelated PID %s.\n' "${existing_pid}"
  else
    rm -f -- "${PID_FILE}"
    printf '[start] Removed stale PID file.\n'
  fi
fi

response_file="$(mktemp "${TMPDIR:-/tmp}/editpicture-comfy-launch.XXXXXX")"
trap 'rm -f -- "${response_file}"' EXIT

if ! comfy --json --workspace="${COMFYUI_WORKSPACE}" launch --background -- \
  --listen "${COMFYUI_HOST}" \
  --port "${COMFYUI_PORT}" \
  --extra-model-paths-config "${MODEL_CONFIG}" \
  --input-directory "${REPO_ROOT}/input" \
  --output-directory "${REPO_ROOT}/output" >"${response_file}" 2>&1; then
  cp -- "${response_file}" "${LAUNCH_RESPONSE_FILE}"
  sed -n '1,120p' "${response_file}" >&2
  fail "comfy-cli could not start ComfyUI (CLI response: ${LAUNCH_RESPONSE_FILE})"
fi
cp -- "${response_file}" "${LAUNCH_RESPONSE_FILE}"

launch_pid="$(extract_pid "${response_file}" || true)"
[[ "${launch_pid}" =~ ^[1-9][0-9]*$ ]] || fail "ComfyUI started but no supervisor PID was found in comfy-cli JSON (CLI response: ${LAUNCH_RESPONSE_FILE})"

server_pid=""
probe_file="$(mktemp "${TMPDIR:-/tmp}/editpicture-comfy-server.XXXXXX")"
for _attempt in {1..40}; do
  if comfy --json --workspace="${COMFYUI_WORKSPACE}" stop --port "${COMFYUI_PORT}" --dry-run >"${probe_file}" 2>&1; then
    candidate_pid="$(extract_pid "${probe_file}" || true)"
    if [[ "${candidate_pid}" =~ ^[1-9][0-9]*$ ]] && process_matches_workspace "${candidate_pid}" "${COMFYUI_WORKSPACE}" "${launch_pid}"; then
      server_pid="${candidate_pid}"
      break
    fi
  fi
  sleep 0.25
done
rm -f -- "${probe_file}"
[[ "${server_pid}" =~ ^[1-9][0-9]*$ ]] || \
  fail "ComfyUI launch returned supervisor PID ${launch_pid}, but the server PID could not be safely verified; inspect ${COMFYUI_WORKSPACE}/user/comfyui_${COMFYUI_PORT}.log"
printf '%s\n' "${server_pid}" >"${PID_FILE}"

printf '[start] ComfyUI started: http://%s:%s (server PID %s, launch supervisor PID %s)\n' "${COMFYUI_HOST}" "${COMFYUI_PORT}" "${server_pid}" "${launch_pid}"
printf '[start] Runtime log: %s/user/comfyui_%s.log\n' "${COMFYUI_WORKSPACE}" "${COMFYUI_PORT}"
printf '[start] CLI response: %s\n' "${LAUNCH_RESPONSE_FILE}"
