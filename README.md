# claude_and_goose

An evaluation harness for a two-agent code workflow:

- **Claude Code** is the planner. It reads context, decomposes work,
  and files structured GitHub Issues.
- **Goose** is the executor. It reads one issue at a time, executes
  its subtasks, comments with results, and opens a PR.

This repo holds the recipes, prompts, and eval results. It is *not*
the target project — it is the rig.

## Pieces

| Path                          | Purpose |
|-------------------------------|---------|
| `CLAUDE.md`                   | What Claude Code reads on every session |
| `goose.yaml`                  | Provider + extension config (Ollama on `bazzite.local`, `qwen3.6:latest`) |
| `recipes/execute-issue.yaml`  | Core recipe: read issue → execute subtasks → PR |
| `recipes/plan-epic.yaml`      | Stub for future Goose-driven issue authoring |
| `prompts/goose-system.md`     | System prompt Goose runs with |
| `prompts/issue-format.md`     | Canonical issue template |
| `evals/`                      | One folder per eval run |
| `scripts/new-eval.sh`         | Scaffold a new `evals/eval-NN/` directory |

## Execution environment

Ollama host (`bazzite.local`):

- AMD Ryzen 9 9900X (12C/24T)
- 96 GB DDR5
- NVIDIA RTX 5090, 32 GB VRAM
- Running `qwen3.6:latest` (36B params, Q4_K_M, ~24 GB)

## Running an eval

1. A `goose-task` issue exists, is `ready-for-execution`, and has no
   open dependencies.
2. Install Goose (see https://goose-docs.ai). Not installed by this
   repo.
3. Point Goose at this config and verify:
   ```
   export GOOSE_ADDITIONAL_CONFIG_FILES="$(pwd)/goose.yaml"
   export GITHUB_PERSONAL_ACCESS_TOKEN=...   # for the github MCP extension
   goose info -v                              # confirm provider/model/extensions resolved
   ```
4. Scaffold an eval directory and run the recipe:
   ```
   ./scripts/new-eval.sh 01
   goose run --recipe recipes/execute-issue.yaml \
     --params issue_number=1 \
     | tee evals/eval-01/goose-session.log
   ```
5. Write `evals/eval-01/result.md` (template scaffolded by the script).

## Status

Pre-eval-01. Harness is freshly scaffolded — nothing has been run end
to end yet. See issue #1.
