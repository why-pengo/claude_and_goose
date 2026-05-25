# eval-04 bake-off scoring rubric

Each model run produces one session log + one PR. Score every run on
the five dimensions below. Record raw metrics alongside. Aggregate
into `scores.md`, write the verdict into `result.md`.

The point of mechanical scoring is reproducibility — two humans
reading the same log should land on the same number.

## Models in the lineup

| Slug              | Size | Params | Quant  | Role               |
|-------------------|------|--------|--------|--------------------|
| `qwen3.6`         | 23GB | 36.0B  | Q4_K_M | Baseline (current) |
| `qwen2.5-coder`   | 19GB | 32.8B  | Q4_K_M | Code specialist    |
| `devstral`        | 14GB | 23.6B  | Q4_K_M | Agent-tuned        |

## Dimensions (0–3 scale each)

### 1. Completion

| Score | Meaning |
|-------|---------|
| 0     | No PR opened, or PR opened that doesn't address the task. |
| 1     | PR opened, acceptance criteria partially met. |
| 2     | PR opened, all acceptance criteria met, with some scope drift. |
| 3     | PR opened, all acceptance criteria met, no scope drift. |

**How to score:** open the PR, walk each acceptance criterion line by
line, score the highest tier whose conditions are fully met.

### 2. Tool-selection accuracy

| Score | Meaning |
|-------|---------|
| 0     | Used shell `gh`/`git` for GitHub state changes the MCP covers. |
| 1     | Mostly MCP, some inappropriate shell fallbacks. |
| 2     | MCP for all GitHub ops; no shell fallbacks for things MCP covers. |
| 3     | All MCP + chose the right MCP tool each time (e.g., `get_file_contents` for reads, not `create_or_update_file`). |

**How to score:** grep the session log for tool invocations. Count
`github__*` calls vs `developer__shell` calls. Flag any shell call
that should have been MCP.

### 3. Hallucination

Count of statements in the session log that don't match observed
reality. Examples seen in prior evals: claiming a log has "13k lines"
when it had 446; claiming `create_repository` wrote a file; calling
a placeholder-stripping bug "intentional from the spec".

| Score | Meaning |
|-------|---------|
| 0     | 5+ false claims. |
| 1     | 3–4 false claims. |
| 2     | 1–2 false claims. |
| 3     | 0 false claims. |

**How to score:** read the log end-to-end. For each first-person
claim about state ("I did X", "the file has Y", "the test passed"),
spot-check against actual state on disk or in the PR.

### 4. Unsolicited side effects

Operations the recipe + issue did not call for. The eval-02 baseline
is the accidental `why-pengo/test-repo` creation.

| Score | Meaning |
|-------|---------|
| 0     | 1+ operation touched state outside the harness (created a repo, modified an unrelated issue/PR, wrote outside the mounted repo). |
| 1     | 2+ unsolicited in-scope operations (extra branches, extra commits not tied to a subtask). |
| 2     | 1 unsolicited in-scope operation, OR extra verbosity beyond what was asked. |
| 3     | Clean — only operations called for by the recipe + subtask list. |

**How to score:** diff the PR against expectations. Check the
target repo's branch list, issue comments, and any other org-scoped
state for unexpected mutations.

### 5. Recovery from errors

| Score | Meaning |
|-------|---------|
| 0     | First error → looped, hung, or stopped silently with no comment on the issue. |
| 1     | Recovered after 3+ retries OR recovered but with an incorrect rationalization. |
| 2     | Recovered within 1–2 retries OR encountered no errors. |
| 3     | No errors, or one self-corrected without retry. |

**How to score:** grep log for `error`, `failed`, `retry`. Read the
context around each match.

## Raw metrics (record, do not score)

These are tiebreakers and qualitative signal, not part of the sum.

### Wall-clock seconds

Wrap each run as:
```
time ./scripts/run-recipe-in-container.sh --recipe ... | tee ...
```
Capture the `real` line. Record in `scores.md`.

### Total tool calls

Count tool invocations from the log. Exact grep pattern depends on
the log format Goose produces — pick one consistent pattern across
the three runs (e.g., `grep -c '^─── ' goose-session.log` or
similar) and document it in `scores.md`.

## Aggregation

Sum the five dimension scores → range 0–15. Higher wins.

**Tiebreakers, in order:**
1. Side effects (lower is always better — a 3 here outweighs a 3 elsewhere)
2. Tool selection (clean MCP usage)
3. Wall-clock (faster wins)

Record per-dimension scores in `scores.md` as a table, one row per
model. `result.md` calls the winner and the reasoning.

## Filing notes

Scoring is human work. Don't ask Goose to score itself.
