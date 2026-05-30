# eval-05 result

Same sandbox task (#24), same recipe, same container, two back-to-back runs with different model warmth. Both failed, **with different failure modes** — devstral's behavior is stochastic, not deterministic.

## What ran

- Recipe: `recipes/execute-issue.yaml`
- Params: `--params issue_number=24`
- Model: `devstral:latest` (via env override; `goose.yaml` default is `qwen3.6:latest`)
- Config: `OLLAMA_STREAM_TIMEOUT: 60` (landed via PR #23)
- Container: `claude-and-goose-runtime` (Goose 1.35.0 + github-mcp-server 1.0.5)

## Run 1 — cold model

Session log: `goose-session.log`. Model state: cold (qwen2.5-coder curl ~10 min prior evicted devstral from VRAM).

**Devstral made zero tool calls and hallucinated the entire workflow.**

| Expected side effect | Actually happened |
|---|---|
| `▸ issue_read github` tool call | None in log |
| Branch `goose/issue-24-...` created | No `goose/` branches on remote |
| File `scripts/check-mcp.sh` pushed | Not in tree |
| PR opened with `Closes #24` | No new PR |
| Comment posted on issue #24 | No comments on #24 |

The session log narrates a complete successful workflow despite none of it happening:

- **Fabricated issue body** — log claims #24 was "Fix grammar in README.md" with subtasks about Python 3 text. Issue #24 is about adding `scripts/check-mcp.sh`; nothing matches.
- **Fabricated Goose UI affordance** — `<sub>(You will not see output here because I'm using silent mode for tool calls.)</sub>`. Goose has no "silent mode"; real tool markers are `▸ <name>`.
- **Fabricated workflow** — branch created, file edited, PR opened, comment posted. All false.
- **"✅ Task Completed"** sign-off.

## Run 2 — warm model

Session log: `goose-session-run2.log`. Model state: warm (run 1 had loaded devstral into VRAM ~30s prior).

**Devstral called tools this time** — `issue_read`, `list_branches`, `create_branch`, `get_file_contents`, `push_files`, `create_pull_request` — and produced real side effects on GitHub. But every artifact is broken in some way:

| Required behaviour | What devstral did |
|---|---|
| Branch named `goose/issue-24-<slug>` | Created `feature/issue-24-add-mcp-check-script` — wrong prefix (recipe + system prompt both require `goose/`) |
| Script per spec (`set -euo pipefail`, `command -v`, `--version`) | Pushed file with **broken syntax**: stray `OLLAMA_HOST=...` line carried over from reference script, `exit 1` mangled into `ex  t 1` (whitespace mid-keyword) |
| PR with `Closes #24` | PR #26 opened, body has no `Closes #24` line. Also typos ("the/github-mcp-server"). |
| Verification subtasks checked truthfully | Body claims "[x] Checked that the script uses set -euo pipefail" — that's true, but it doesn't check the broken `exit` line |
| Comment on #24 | Step 6 skipped — no comment posted |

If a human reviewer ran the script as merged, it would fail with `command not found: ex` (the mangled `exit`). The PR is unmergeable as-is.

## Verdict

Verdict: **FAIL (both runs).**

Two different failure modes on consecutive runs of the same input:

- Run 1: silent hallucination — looks successful in log, nothing actually happened.
- Run 2: real tool calls — but broken file content, wrong branch convention, missing required PR sections.

Neither produced a mergeable artifact. The model is unsuitable as a Goose executor in this harness regardless of timeout tuning.

## Implications for #23 / eval-04 framing

The `OLLAMA_STREAM_TIMEOUT: 60` mitigation from PR #23 was harmless but didn't fix anything for devstral. Run 1 ran a long narration without any timeout firing, and run 2's tool calls would have worked at any timeout because the model was warm. The "cold-load flake" diagnosis from PR #23 was wrong; the real failure mode is "devstral can't reliably execute structured multi-step recipes — sometimes it doesn't call tools at all, sometimes it does but mangles the content."

The eval-04 `result.md` / `scores.md` annotations should be revised to drop the "not a structural problem" claim.

## Cleanup needed

- PR #26 (devstral's broken submission) — close without merging.
- Branch `feature/issue-24-add-mcp-check-script` — delete after closing PR.
- Issue #24 — task itself is valid; could re-run with `qwen3.6:latest` to confirm the task works.

## Next time

- Don't treat session-log narration as evidence of work. Always verify against `gh pr list`, `gh issue view --comments`, and remote branches.
- Add a post-run smoke check that requires at least one `▸ ` line OR at least one real side effect (branch / PR / comment) before claiming the executor "did something."
- Stop trying to make devstral work in this harness. Eval-04 + eval-05 (two runs) = three independent failure modes. The model is structurally a bad fit for Goose's tool-or-nothing execution model.
