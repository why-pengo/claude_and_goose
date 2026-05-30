# feat: add scripts/post-run-check.sh to verify goose-run side effects

## Goal

Add a single-file bash helper that verifies a Goose run produced real artifacts — at least one tool call in the session log, plus a real GitHub side effect (branch or PR) tied to a given issue number. The script is the canonical answer to "did the goose run actually do anything, or just narrate intent?" — a question eval-05 made us care about.

## Context

- See `evals/eval-05/result.md` for the motivating failure modes — three of the five runs produced session logs that looked plausible but had zero real artifacts on GitHub.
- The check operates on local + remote state only. It does not modify anything.
- Session log marker convention: Goose prints `▸ <tool_name>` for each tool call. A log with **zero** `▸ ` lines means the model never invoked a tool, regardless of how confidently it narrated.
- Companion script style: model after `scripts/check-ollama.sh` (set -euo pipefail, header comment block, minimal external deps — just `gh` and standard POSIX).
- File-mode caveat: MCP `push_files` does not expose a `mode` field, so you cannot set the executable bit when pushing. List `chmod +x scripts/post-run-check.sh` under `## Follow-ups` in the PR body. Do not invent a workaround script.

## Subtasks

- [ ] Create `scripts/post-run-check.sh` with:
  - `#!/usr/bin/env bash` shebang
  - `set -euo pipefail`
  - 5–8 line header comment block: what it does, usage examples, exit codes
  - Argument parsing:
    - Required: `ISSUE_NUMBER` (positional arg 1)
    - Optional: `SESSION_LOG_PATH` (positional arg 2). If omitted, default to the most recently modified `evals/eval-*/goose-session*.log`.
  - Three checks, each printing one line with `PASS` or `FAIL`:
    1. **Tool calls present** — count lines in the session log matching the regex `^[[:space:]]*▸ `. PASS if count >= 1, FAIL otherwise. Print the count.
    2. **Branch on remote** — use `gh api repos/{owner}/{repo}/branches` to look for any branch named `goose/issue-N-*` (where N is the issue number). Detect owner/repo via `gh repo view --json owner,name`. PASS if at least one match, FAIL otherwise. Print the matching branch name.
    3. **PR closing the issue** — use `gh pr list --state all --search 'closes #N in:body'` to look for any PR (open or merged) whose body references `Closes #N`. PASS if at least one match, FAIL otherwise. Print the PR number.
  - Final line: `RESULT: PASS` if check 1 passes AND (check 2 OR check 3) passes; `RESULT: FAIL` otherwise.
  - Exit code: 0 on PASS, 1 on FAIL.
- [ ] Push the new file via the `push_files` MCP tool (single-entry call).
- [ ] Open a PR with `Closes #<this-issue>` in the body. PR body must include:
  - `## Summary` — 2–3 bullets on what the script does
  - `## Verification` — show the output of running it against eval-05 (issue #24); both `RESULT: FAIL` is the expected outcome there since #24 had no successful PR
  - `## Follow-ups` — single line: `chmod +x scripts/post-run-check.sh post-merge (MCP push_files cannot set mode)`

## Acceptance criteria

- File `scripts/post-run-check.sh` exists on the goose branch.
- File contains `set -euo pipefail`.
- File contains `gh api repos` (one of the API calls) and `gh pr list` (the other) — verify by grep.
- File contains the regex `^[[:space:]]*▸ ` (the tool-call marker check).
- Running `bash scripts/post-run-check.sh 24` against the merged branch prints three `[CHECK N]` lines and one `RESULT:` line. The result line says `FAIL` for #24 (since no PR was merged for that issue).
- PR body includes the `## Follow-ups` line about the executable bit.

## Out of scope

- Modifying `scripts/check-ollama.sh` or any other existing file.
- Updating `README.md` to reference the new script.
- Adding the script to any CI workflow (none exists yet).
- Inventing a `permissions.sh` or chmod helper.
- Adding bash flags beyond the two positional args (no `--issue`, no `--log`, no `--repo`).
