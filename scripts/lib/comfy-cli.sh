#!/usr/bin/env bash

COMFY_CLI_MIN_VERSION="1.13.0"

version_at_least() {
  local actual="$1" minimum="$2" index
  local old_ifs="${IFS}"
  IFS=.
  set -- ${actual}
  local actual_parts=("${1:-0}" "${2:-0}" "${3:-0}")
  set -- ${minimum}
  local minimum_parts=("${1:-0}" "${2:-0}" "${3:-0}")
  IFS="${old_ifs}"
  for index in 0 1 2; do
    if ((10#${actual_parts[index]} > 10#${minimum_parts[index]})); then
      return 0
    fi
    if ((10#${actual_parts[index]} < 10#${minimum_parts[index]})); then
      return 1
    fi
  done
  return 0
}

check_comfy_cli() {
  command -v comfy >/dev/null 2>&1 || {
    printf 'comfy-cli is not on PATH' >&2
    return 1
  }

  local output version install_help launch_help stop_help
  output="$(comfy --version 2>&1)" || {
    printf 'could not run comfy --version' >&2
    return 1
  }
  version="$(sed -nE 's/.*[^0-9]([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' <<<"${output}" | head -n 1)"
  [[ -n "${version}" ]] || {
    printf 'could not parse comfy-cli version from: %s' "${output}" >&2
    return 1
  }
  version_at_least "${version}" "${COMFY_CLI_MIN_VERSION}" || {
    printf 'comfy-cli %s is too old; version %s or newer is required' "${version}" "${COMFY_CLI_MIN_VERSION}" >&2
    return 1
  }

  install_help="$(comfy install --help 2>&1)" || return 1
  launch_help="$(comfy launch --help 2>&1)" || return 1
  stop_help="$(comfy stop --help 2>&1)" || return 1
  grep -q -- '--m-series' <<<"${install_help}" &&
    grep -q -- '--fast-deps' <<<"${install_help}" &&
    grep -q -- '--background' <<<"${launch_help}" &&
    grep -q -- '--dry-run' <<<"${stop_help}" || {
      printf 'comfy-cli lacks required install/launch/stop options' >&2
      return 1
    }
}

extract_pid() {
  local response_file="$1" pid=""
  if command -v python3 >/dev/null 2>&1; then
    pid="$(python3 - "${response_file}" 2>/dev/null <<'PY'
import json
import sys

text = open(sys.argv[1], encoding="utf-8").read()
decoder = json.JSONDecoder()
found = []
for index, char in enumerate(text):
    if char not in "{[":
        continue
    try:
        value, _ = decoder.raw_decode(text[index:])
    except json.JSONDecodeError:
        continue
    stack = [value]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            candidate = item.get("pid")
            if isinstance(candidate, int) and candidate > 0:
                found.append(candidate)
            stack.extend(item.values())
        elif isinstance(item, list):
            stack.extend(item)
if found:
    print(found[-1])
PY
)"
  fi
  if [[ ! "${pid}" =~ ^[1-9][0-9]*$ ]]; then
    pid="$(sed -nE 's/.*"pid"[[:space:]]*:[[:space:]]*([1-9][0-9]*).*/\1/p' "${response_file}" | tail -n 1)"
  fi
  [[ "${pid}" =~ ^[1-9][0-9]*$ ]] || return 1
  printf '%s\n' "${pid}"
}

process_matches_workspace() {
  local pid="$1" workspace="$2" launch_pid="${3:-}" ppid command cwd=""
  kill -0 "${pid}" 2>/dev/null || return 1

  if [[ "${launch_pid}" =~ ^[1-9][0-9]*$ ]]; then
    ppid="$(ps -p "${pid}" -o ppid= 2>/dev/null | tr -d '[:space:]')"
    [[ "${ppid}" == "${launch_pid}" ]] && return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    cwd="$(lsof -a -p "${pid}" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1)"
    if [[ -n "${cwd}" ]]; then
      local physical_workspace
      physical_workspace="$(cd -- "${workspace}" 2>/dev/null && pwd -P)" || return 1
      [[ "${cwd}" == "${physical_workspace}" ]] && return 0
    fi
  fi

  command="$(ps -p "${pid}" -o command= 2>/dev/null)"
  [[ "${command}" == *"${workspace}"* && "${command}" == *"main.py"* ]]
}
