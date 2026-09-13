#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

fail() { printf '[comfy-local] ERROR: %s\n' "$*" >&2; exit 1; }

reject_unsafe_arguments() {
  local argument
  for argument in "$@"; do
    case "${argument}" in
      --where|--where=*|--host|--host=*|--port|--port=*|\
      --workspace|--workspace=*|--recent|--no-recent|--here|--no-here|\
      --allow-spend|--allow-spend=*|--api-key*|--workflow-id|--workflow-id=*|\
      --prompt|--prompt=*|--all|--overwrite|--in-place)
        fail "Argument is not allowed by the local image-generation wrapper: ${argument}"
        ;;
    esac
  done
}

validate_command() {
  local arguments=("$@")
  local command="" command_index=-1 argument index=0
  local saw_terminal_option=false

  for argument in "${arguments[@]}"; do
    if [[ -z "${command}" ]]; then
      case "${argument}" in
        --version|-v|--help|--help-json|--install-completion|--show-completion)
          saw_terminal_option=true
          ;;
        --json|--json-stream|--no-json|--skip-prompt|--no-skip-prompt)
          ;;
        --*)
          fail "Unsupported global option before command: ${argument}"
          ;;
        *)
          command="${argument}"
          command_index=${index}
          ;;
      esac
    fi
    index=$((index + 1))
  done

  if [[ -z "${command}" ]]; then
    [[ "${saw_terminal_option}" == true ]] || fail "A permitted comfy command is required"
    return
  fi

  case "${command}" in
    help|discover|system-stats|run|upload|download|jobs|workflow|nodes) ;;
    *) fail "Command is not allowed by the local image-generation wrapper: ${command}" ;;
  esac

  local subcommand="${arguments[$((command_index + 1))]:-}"
  if [[ "${subcommand}" == "--help" || "${subcommand}" == "-h" ]]; then
    return
  fi
  case "${command}" in
    jobs)
      case "${subcommand}" in
        status|wait|watch|cancel) ;;
        "") ;;
        *) fail "jobs subcommand is not allowed: ${subcommand}" ;;
      esac
      ;;
    workflow)
      case "${subcommand}" in
        slots|set-slot|validate) ;;
        "") ;;
        *) fail "workflow subcommand is not allowed: ${subcommand}" ;;
      esac
      if [[ "${subcommand}" == "set-slot" ]]; then
        local has_stdout=false set_slot_help=false
        for argument in "${arguments[@]}"; do
          case "${argument}" in
            --stdout) has_stdout=true ;;
            --help|-h) set_slot_help=true ;;
          esac
        done
        [[ "${has_stdout}" == true || "${set_slot_help}" == true ]] || \
          fail "workflow set-slot requires --stdout; tracked templates must not be edited in place"
      fi
      ;;
    nodes)
      case "${subcommand}" in
        ls|show|search|upstream|downstream|path|types|categories|widget-catalog) ;;
        "") ;;
        *) fail "nodes subcommand is not allowed: ${subcommand}" ;;
      esac
      ;;
    run)
      local has_workflow=false has_help=false
      for argument in "${arguments[@]}"; do
        case "${argument}" in
          --workflow|--workflow=*) has_workflow=true ;;
          --help|-h) has_help=true ;;
        esac
      done
      [[ "${has_workflow}" == true || "${has_help}" == true ]] || \
        fail "run requires an explicit --workflow"
      ;;
    upload)
      local has_no_overwrite=false upload_help=false
      for argument in "${arguments[@]}"; do
        case "${argument}" in
          --no-overwrite) has_no_overwrite=true ;;
          --help|-h) upload_help=true ;;
        esac
      done
      [[ "${has_no_overwrite}" == true || "${upload_help}" == true ]] || \
        fail "upload requires --no-overwrite"
      ;;
  esac
}

load_editpicture_config "${REPO_ROOT}"
normalize_comfyui_port || fail "COMFYUI_PORT must be a decimal integer from 1 through 65535"
[[ "${COMFYUI_HOST}" == "127.0.0.1" || "${COMFYUI_HOST}" == "localhost" || "${COMFYUI_HOST}" == "::1" ]] || \
  fail "Refusing non-local COMFYUI_HOST=${COMFYUI_HOST}"
command -v comfy >/dev/null 2>&1 || fail "comfy-cli is not on PATH; run ./scripts/setup.sh"
[[ -n "${COMFYUI_WORKSPACE}" ]] || fail "COMFYUI_WORKSPACE is empty"

url_host="${COMFYUI_HOST}"
[[ "${url_host}" == *:* ]] && url_host="[${url_host}]"
COMFY_LOCAL_URL="http://${url_host}:${COMFYUI_PORT}"
COMFY_CLI_NO_REMOTE_REFRESH=1
export COMFY_LOCAL_URL COMFY_CLI_NO_REMOTE_REFRESH

[[ -z "${COMFY_API_KEY:-}" ]] || fail "COMFY_API_KEY is set; paid/API-node credentials are not allowed through this wrapper"
reject_unsafe_arguments "$@"
validate_command "$@"

exec comfy --workspace="${COMFYUI_WORKSPACE}" --where local "$@"
