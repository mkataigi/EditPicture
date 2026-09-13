---
name: editpicture-comfy-image
description: Generate or evaluate images through this repository's local ComfyUI installation. Use for image-generation requests in EditPicture that should run a committed workflow on the user's Mac; do not use for cloud or paid image services.
---

# EditPicture Comfy Image

Use ComfyUI only as the local backend configured by this checkout. Run repository commands from the repository root.

## Non-negotiable boundaries

- Use `scripts/comfy-local.sh` for every direct `comfy` invocation. It pins both the workspace and `--where local` and refuses a non-loopback target.
- Do not download, update, replace, or delete models or custom nodes without an explicit user request naming that action. Never delete the stable `models/` directories.
- Do not switch models, workflows, or the local backend to make a failed generation succeed unless the user has explicitly approved that exact local, unpaid fallback. Unapproved fallback is prohibited; cloud routes and paid/API nodes remain outside this skill.
- Never pass `--allow-spend`, use `--where cloud`, or send prompts, images, workflows, or credentials to a remote service.
- Do not use the bundled `comfy run --prompt` workflow. It may substitute a checkpoint. Run an explicit workflow file from `comfy/workflows/` or an explicit user-provided path.
- Keep reference and generated images untracked. Never add files under `input/`, `output/`, or experiment artifact directories to Git.

## Run an image task

1. Resolve the user's requested workflow, model choices, prompt, dimensions, seed, and output count. Preserve a backend-neutral semantic prompt separately from any FLUX-specific prompt. If a required choice is absent and cannot be read from the selected workflow or experiment configuration, stop and identify that choice; do not guess a model or backend. If the user has already approved a specific local, unpaid fallback, apply only that fallback and repeat the full preflight before continuing.
2. Read [references/comfy-cli-1.20.md](references/comfy-cli-1.20.md) before constructing or changing CLI invocations.
3. Preflight the local backend:

   ```bash
   ./scripts/healthcheck.sh
   ./scripts/comfy-local.sh system-stats
   ```

   If the server is not running, use `./scripts/start.sh`, then repeat the health check. Do not change the bind address.
4. Inspect the exact workflow before execution. Prefer a committed API-format workflow. For a frontend-format template, inspect its declared slots and write changes to `comfy/workflows/tmp/`; never edit a tracked template in place. Convert the variant to API format with `run --workflow ... --print-prompt`, then validate that exact API workflow. Refuse any paid/partner API node or undeclared model fallback.
5. Files already under this checkout's `input/` directory are directly visible to the managed server; do not upload them. For a user-approved source outside this directory, upload it with `upload --no-overwrite`, capture the returned server filename, and write that exact filename into the temporary workflow variant. Never silently replace an existing server input.
6. Submit once with structured output and no detached watcher. Capture the returned `prompt_id`:

   ```bash
   ./scripts/comfy-local.sh run --workflow comfy/workflows/<workflow>.json --json --no-watch
   ```

   Never start an unbounded retry loop. Respect a user-specified finite output count; if the user gives no count, generate one candidate at a time with a default ceiling of four total candidates.
7. Wait with a finite wall-clock limit:

   ```bash
   ./scripts/comfy-local.sh jobs wait <prompt_id> --poll-interval 5 --timeout 900
   ```

   On timeout or interruption, inspect that prompt ID. If it is non-terminal, cancel only that job with `jobs cancel <prompt_id>`—never `--all` and never an unrelated queue entry.
8. Download only that job's outputs to `experiments/<run-id>/artifacts`, then visually inspect every candidate with the available image viewer. Check both obvious defects and the requested composition/style; a completed job alone is not proof of success.
9. Record provenance under `experiments/<run-id>/`: the semantic prompt, derived backend prompt, workflow path and content hash, declared model filenames, seed, dimensions, sampler/settings, prompt ID, timestamps, CLI/backend versions, and output paths. Keep small text/JSON metadata trackable; put generated images and large results in an ignored `artifacts/` or `output/` subdirectory.

Stop when the user goal is satisfied, after the user's explicit finite candidate count, after four total candidates when no count was given, after the same failure occurs twice, or immediately on an unapproved missing dependency, abnormal API response, or user interruption. An explicitly approved local, unpaid fallback may proceed only after a fresh preflight. Do not stop the shared ComfyUI server after a run unless the user explicitly requests it or you have confirmed no other jobs use it.

Report the workflow, model filenames, prompt ID, reviewed output paths, and any unmet constraints. Do not claim visual success unless the output was actually inspected.
