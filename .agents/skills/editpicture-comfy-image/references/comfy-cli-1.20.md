# comfy-cli 1.20 local command reference

This project verified the following surface against `comfy-cli` 1.20.0. Re-run each command's `--help` before relying on it after a CLI upgrade.

Always invoke commands through `./scripts/comfy-local.sh`. The wrapper loads this checkout's runtime configuration, rejects non-loopback hosts, normalizes the port, exports `COMFY_LOCAL_URL`, disables remote node metadata refresh, and forces the configured workspace and `--where local`. It rejects user-supplied routing, host, port, workspace, credential, spend, implicit-prompt, overwrite, and broad `--all` flags, and permits only the local inspection and workflow commands used by this skill.

## Preflight and lifecycle

```bash
./scripts/healthcheck.sh
./scripts/start.sh
./scripts/stop.sh
./scripts/comfy-local.sh --version
./scripts/comfy-local.sh system-stats
```

`healthcheck.sh` distinguishes healthy (`0`), unreachable/not running (`1`), and abnormal API response (`2`). Use the repository lifecycle scripts instead of raw `comfy launch` or `comfy stop`; they enforce loopback binding and PID verification.

## Workflow submission

```bash
./scripts/comfy-local.sh workflow slots comfy/workflows/example.json
./scripts/comfy-local.sh --no-json workflow set-slot comfy/workflows/example.json <slot>=<value> --stdout > comfy/workflows/tmp/run.json
./scripts/comfy-local.sh --no-json run --workflow comfy/workflows/tmp/run.json --print-prompt > comfy/workflows/tmp/run.api.json
./scripts/comfy-local.sh workflow validate --workflow comfy/workflows/tmp/run.api.json
./scripts/comfy-local.sh run --workflow comfy/workflows/tmp/run.api.json --json --no-watch
```

`workflow slots` and `workflow set-slot` operate on frontend-format workflows. Always use `--stdout` with `--no-json` and redirect to an ignored temporary variant; `set-slot` otherwise edits the tracked input in place. `run --workflow` accepts API-format or exported UI-format JSON. UI-format conversion contacts `/object_info`; API-format preview does not require a server. Validate the converted API-format file before submission. `--json` emits NDJSON events and ends with an envelope; preserve the returned `prompt_id`. `--no-watch` prevents a second detached watcher when the agent will monitor the job itself.

Do not use `run --prompt`: its bundled text-to-image workflow prefers an SD 1.5 checkpoint and may substitute an installed checkpoint. Do not pass `--allow-spend`; it authorizes paid partner nodes.

## One-job observation and cancellation

```bash
./scripts/comfy-local.sh jobs status <prompt_id>
./scripts/comfy-local.sh jobs wait <prompt_id> --poll-interval 5 --timeout 900
./scripts/comfy-local.sh jobs watch <prompt_id>
./scripts/comfy-local.sh jobs cancel <prompt_id>
```

`jobs wait --timeout` is a total wall-clock deadline. Prefer it to `run --wait`, whose `--timeout` is a per-event silence timeout rather than a total execution deadline. Never use `jobs wait --all` for an agent-owned run. Cancel only the prompt ID returned by the current submission.

## Inputs

```bash
./scripts/comfy-local.sh upload /path/outside/repository/reference.png --no-overwrite
```

Files already under this checkout's ignored `input/` directory need no upload because `scripts/start.sh` mounts that directory as the server input. Use `upload` only for a user-approved file outside that directory. It overwrites by default, so always pass `--no-overwrite`; capture the response's server-side filename and write that exact name into the temporary workflow variant rather than using the source path.

## Outputs

ComfyUI launched by `scripts/start.sh` writes into this repository's ignored `output/` directory. If an explicit copy is needed for a completed job:

```bash
./scripts/comfy-local.sh download <prompt_id> --out-dir experiments/<run-id>/artifacts
```

Generated output and artifact directories are ignored by Git. Record their relative paths in the experiment's small provenance metadata.
