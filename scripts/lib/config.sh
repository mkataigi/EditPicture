#!/usr/bin/env bash

# Load clone-local settings without allowing runtime.env to overwrite values
# explicitly supplied by the caller. Compatible with macOS Bash 3.2.
load_editpicture_config() {
  local repo_root="$1"
  local runtime_file="${repo_root}/comfy/config/runtime.env"
  local env_parent_set=0 env_workspace_set=0 env_host_set=0 env_port_set=0
  local env_parent="" env_workspace="" env_host="" env_port=""

  if [[ "${COMFYUI_INSTALL_PARENT+x}" == x ]]; then
    env_parent_set=1
    env_parent="${COMFYUI_INSTALL_PARENT}"
  fi
  if [[ "${COMFYUI_WORKSPACE+x}" == x ]]; then
    env_workspace_set=1
    env_workspace="${COMFYUI_WORKSPACE}"
  fi
  if [[ "${COMFYUI_HOST+x}" == x ]]; then
    env_host_set=1
    env_host="${COMFYUI_HOST}"
  fi
  if [[ "${COMFYUI_PORT+x}" == x ]]; then
    env_port_set=1
    env_port="${COMFYUI_PORT}"
  fi

  unset COMFYUI_INSTALL_PARENT COMFYUI_WORKSPACE COMFYUI_HOST COMFYUI_PORT
  if [[ -f "${runtime_file}" ]]; then
    # shellcheck disable=SC1090
    source "${runtime_file}"
  fi

  if (( env_parent_set )); then
    COMFYUI_INSTALL_PARENT="${env_parent}"
  else
    COMFYUI_INSTALL_PARENT="${COMFYUI_INSTALL_PARENT:-${HOME}/.local/share/editpicture/comfy}"
  fi

  if (( env_workspace_set )); then
    COMFYUI_WORKSPACE="${env_workspace}"
  elif (( env_parent_set )); then
    # An explicit parent describes an installation target, so do not retain a
    # workspace path belonging to the runtime file's different parent.
    COMFYUI_WORKSPACE="${COMFYUI_INSTALL_PARENT}/ComfyUI"
  else
    COMFYUI_WORKSPACE="${COMFYUI_WORKSPACE:-${COMFYUI_INSTALL_PARENT}/ComfyUI}"
  fi

  if (( env_host_set )); then
    COMFYUI_HOST="${env_host}"
  else
    COMFYUI_HOST="${COMFYUI_HOST:-127.0.0.1}"
  fi
  if (( env_port_set )); then
    COMFYUI_PORT="${env_port}"
  else
    COMFYUI_PORT="${COMFYUI_PORT:-8188}"
  fi
  export COMFYUI_INSTALL_PARENT COMFYUI_WORKSPACE COMFYUI_HOST COMFYUI_PORT
}

normalize_comfyui_port() {
  case "${COMFYUI_PORT}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  ((${#COMFYUI_PORT} <= 5)) || return 1
  local decimal_port=$((10#${COMFYUI_PORT}))
  ((decimal_port >= 1 && decimal_port <= 65535)) || return 1
  COMFYUI_PORT="${decimal_port}"
}
