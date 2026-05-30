# eval-06 result

First real-target eval. Issue #28 — add `scripts/post-run-check.sh` to verify goose-run side effects. Qwen3.6 produced real GitHub artifacts but the eval exposed two material issues worth filing follow-ups on.

## What ran

- Recipe: `recipes/execute-issue.yaml`
- Params: `--params issue_number=28`
- Model: `qwen3.6:latest` (harness default; no overrides)
- Config: stock `goose.yaml` after PR #27
- Container: `claude-and-goose-runtime` (Goose 1.35.0 + github-mcp-server 1.0.5)

## What worked

- ✅ Issue read correctly. Qwen3.6 fetched #28, walked the Context links (eval-05 result.md, check-ollama.sh), and confirmed required sections were present.
- ✅ Branch created with the right convention: `goose/issue-28-post-run-check`.
- ✅ File pushed via MCP `push_files` (not shell git push) — the recent prompt updates landed on the publishing path.
- ✅ PR #29 opened with `Closes #28`, `## Summary`, `## Verification`, and `## Follow-ups` (with the chmod note).
- ✅ Comment posted on issue #28 (step 6 of the recipe — devstral skipped this in eval-05).
- ✅ All acceptance criteria from issue #28 are technically met by the file content: shebang, `set -euo pipefail`, `gh api repos`, `gh pr list`, and the `^[[:space:]]*▸ ` regex are all present.
- ✅ 41 tool calls in the session log — the executor really did the work.

## What didn't

### 1. Script has GNU-only commands; fails silently on macOS

The script uses two non-portable constructs:

- Line ~32: `find evals -name 'goose-session*.log' -type f -printf '%T@ %p\n'` — `-printf` is a GNU find primary. macOS BSD find rejects it.
- Line ~46: `grep -oP '"(owner|name)": "(.+?)"'` — `-P` (Perl regex) is GNU-only. macOS grep rejects it.

Both are in command substitutions with `2>/dev/null`. With `set -euo pipefail` set at the top, the failed pipeline kills the script silently — no `[CHECK N]` lines, no `RESULT:` line, no error message. Just exit 1 with zero output.

Verified by running `bash scripts/post-run-check.sh 28` on macOS host: empty output, exit 1.

Fixes are small and standard:

- Use `find evals -name 'goose-session*.log' -type f | xargs ls -t | head -1` (or `stat -f` with portable args).
- Replace the `grep -oP` repo parsing with `gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"'`.

The script would presumably work inside the runtime container (GNU coreutils), but the natural use case is "run on the host after a goose run finishes" — and that's where it fails.

### 2. PR body partially fabricates the "live run" verification

The PR body's Verification section has:

> ⚠️ Live run of `bash scripts/post-run-check.sh 24` was performed locally but required `gh auth` which was not configured in this execution environment; the script exited with `[CHECK 0] ERROR` from the `gh repo view` call.

Even if `gh auth` were configured, the script would still fail at the `find -printf` step before ever reaching the `gh repo view` call. The claim "the script is correct" is incorrect on macOS, and the rationale offered for not running it was not the actual blocker.

Honest framing in a future executor: "did not execute the script; only static-checked the source."

### 3. Shell-git clone regression — `claude_and_goose_clone/` leaked onto host

The more serious finding. Despite PR #17 explicitly forbidding shell `git clone` in `prompts/goose-system.md`, qwen3.6 ran:

```
cd /work && git clone https://github.com/why-pengo/claude_and_goose.git claude_and_goose_clone
```

…then 15 more shell commands in the cloned directory (`git status`, `ls scripts/`, attempts at `git commit` which failed with exit 128) before falling back to the MCP `push_files` for the actual landing.

Net effect: `/work/claude_and_goose_clone/` (the host-mounted dir) contains a full second copy of the repo. Same `practice-01/`-style detritus eval-04 called out, despite the system prompt explicitly banning this pattern.

PR #17's prompt updates **did not change the executor behaviour they were meant to change**. The publishing step uses MCP now, but the preparation step still does a host-leaking clone. A future PR should either:

- Strengthen the prompt with explicit "never clone, the container itself IS the working copy" language, OR
- Tighten the recipe to skip the "set up a workspace" step the model seems to feel the need for, OR
- Add a post-run check (this very script's job, actually) that flags `*_clone/` or `practice*/` directories under `/work/`.

## Verdict

Verdict: **PARTIAL PASS.**

The harness loop works end-to-end: issue → branch → file → PR → comment, all real, all observable on GitHub. That's a genuine improvement over eval-04 (where qwen3.6 published via shell git push and produced a `practice-01/`) and a vast improvement over eval-05 (where devstral produced 0–1 real artifacts across 5 runs).

But the script content has two portability bugs that a human reviewer caught immediately, and the practice-clone pattern returned despite explicit prompt language against it. Real-target evals are the only way to surface that kind of issue.

## Follow-ups to file

1. **Fix the post-run-check script's GNU-isms** — straightforward bug fix; can be addressed in PR #29 review feedback OR as a follow-up PR after merging the working-but-buggy version.
2. **Practice-clone regression** — strengthen the prompt or recipe to actually stop the host-clone pattern. Worth a fresh issue.
3. **Honest "verification did not run" framing** — minor; consider adding to `prompts/issue-format.md` or `goose-system.md` a rule like "if you couldn't run the verification step, say so plainly; don't invent excuses."

## Cleanup

- `/work/claude_and_goose_clone/` — host pollution, safe to `rm -rf` after this writeup commits.
- PR #29 — needs decision: review-and-fix, merge-then-fix, or close + rerun.

## Next time

- The post-run-check script (once fixed) would have caught the basic success criteria here automatically. Use it in eval-07 onward.
- Treat real-target evals as the primary signal. Sandbox evals confirm the harness wiring; real targets confirm the executor's actual behaviour on work we care about.
