# Agent guidance

## Purpose

This repository is the automation and experiment layer for local image generation. Treat ComfyUI as an external image-generation backend controlled through `comfy-cli` and, as the project grows, its HTTP API.

## Image-generation tasks

- Use the repository skill at `.agents/skills/editpicture-comfy-image/SKILL.md` for requests to generate or evaluate images with this local ComfyUI environment.
- Use `scripts/comfy-local.sh` for direct `comfy-cli` commands so the configured workspace and local-only route are explicit.
- Require an explicit workflow for generation. Do not use implicit checkpoint substitution or change the selected model/backend after a failure without the user's explicit approval of that fallback; after an approved change, repeat preflight checks.
- Preflight the server, bound each run and retry count, cancel only the current job by prompt ID, visually review outputs, and record experiment provenance as directed by the skill.
- Do not use paid partner nodes, cloud routing, or remote image services unless the user separately and explicitly changes the scope.

## Safety and repository rules

- Never add model weights or other large model files to Git.
- Never download a model unless the user explicitly asks for that exact download.
- Do not delete `models/` or its category directories. They are stable local mount points.
- Do not commit generated images or reference images from `input/` and `output/`.
- Keep reusable workflow templates in `comfy/workflows/`.
- Keep experiment definitions, notes, and results under `experiments/`; large artifacts stay ignored.
- Prefer generating ComfyUI workflow JSON from compact, semantic experiment configuration instead of hard-coding large workflow JSON in application code.
- Keep semantic prompts backend-neutral. Backend adapters may derive FLUX or future Midjourney prompts from them.
- Use the commands in `scripts/` for setup, startup, shutdown, and health checks whenever possible.
- Keep ComfyUI bound to loopback. Do not change it to an externally reachable host without explicit user approval.
- The default ComfyUI installation is external to the repository at `~/.local/share/editpicture/comfy/ComfyUI`.
- Runtime files in `comfy/config/` contain machine-specific absolute paths and must remain untracked; update the tracked `.example` files when changing their schema.
