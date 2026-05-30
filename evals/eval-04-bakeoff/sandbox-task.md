<!--
File this as a GitHub issue when running eval-04. Suggested command:

  gh issue create \
    --title "feat: add scripts/check-ollama.sh model inventory helper" \
    --label goose-task \
    --label ready-for-execution \
    --body-file evals/eval-04-bakeoff/sandbox-task.md

The HTML comment is invisible in rendered markdown and won't appear
in the filed issue body. Keep one issue open across the three runs —
each model branches from main, opens its own PR. Close PRs without
merging between runs so the next model starts from the same main.
-->

## Goal

Add `scripts/check-ollama.sh`: a small helper that hits the Ollama
host's `/api/tags` endpoint and prints the installed models with
their size, parameter count, and quantization. Exits non-zero with a
clear stderr message if the host is unreachable.

## Context

- The Ollama host setup is documented in `README.md` under the
  "Execution environment" section. The host URL is referenced in
  `goose.yaml`.
- `OLLAMA_HOST` is a full base URL including scheme — the container
  wrapper exports it as `http://<ip>:11434`. Build the endpoint as
  `${OLLAMA_HOST:-http://bazzite.local:11434}/api/tags` (do NOT
  prefix `http://` again — that produces `http://http://...`).
  The Ollama API returns JSON of the form
  `{"models": [{"name": "...", "size": ..., "details": {"parameter_size": "...", "quantization_level": "..."}}, ...]}`.
- `scripts/new-eval.sh` is a good template for the script's shape:
  bash, `set -euo pipefail`, short and self-contained.
- Available tools (host and runtime container): `curl`, `jq`.

## Subtasks

- [ ] Create `scripts/check-ollama.sh` with `#!/usr/bin/env bash` and
      `set -euo pipefail`. Default the host URL to
      `http://bazzite.local:11434`; accept override via `OLLAMA_HOST`.
- [ ] Curl the `/api/tags` endpoint with a 5-second connect timeout.
      On any failure (network, DNS, non-200), print a clear stderr
      message that includes the URL attempted, then exit 1.
- [ ] On success, pipe the JSON through `jq` to print one tab-separated
      row per model with four fields in this order: `NAME`, `SIZE_GB`
      (rounded), `PARAMETER_SIZE`, `QUANTIZATION_LEVEL`. The `size`
      field is bytes — divide by 1e9.
- [ ] Make the script executable (`chmod +x scripts/check-ollama.sh`).
- [ ] Add one short line to `README.md`'s "Execution environment"
      section noting the script (e.g., "Run `./scripts/check-ollama.sh`
      to list models currently on the host.").

## Acceptance criteria

- `./scripts/check-ollama.sh` exits 0 against a reachable Ollama host
  and prints at least one model row.
- The output has one model per line with all four fields present.
- `OLLAMA_HOST=http://invalid.local:99 ./scripts/check-ollama.sh`
  exits 1 with a stderr message naming the URL it tried.
- `ls -l scripts/check-ollama.sh` shows the executable bit set.
- `README.md` mentions the script in one short line under the
  "Execution environment" section.

## Out of scope

- Adding a Makefile target.
- Caching results or storing model history.
- Handling multiple Ollama hosts in one invocation.
- Touching `goose.yaml`, `Dockerfile`, or the container wrapper.
- Refactoring `scripts/new-eval.sh` or any other existing script.
