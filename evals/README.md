# Evals

Each evaluation of the Claude Code → Goose workflow lives in its own
`eval-NN/` directory.

## What goes in each directory

- `issue.md` — verbatim copy of the GitHub issue Goose was given
- `result.md` — written after the run:
  - What ran (recipe + params + model)
  - What worked
  - What didn't
  - One-line verdict: `Verdict: PASS | FAIL | PARTIAL`
  - 3 concrete changes to try in the next eval
- `goose-session.log` — raw Goose stdout. Capture with:
  ```
  goose run --recipe recipes/execute-issue.yaml \
    --params issue_number=N \
    | tee evals/eval-NN/goose-session.log
  ```

## Creating a new eval

```
./scripts/new-eval.sh 02
```

Scaffolds the directory with empty placeholders.

## Why we track these

We're evaluating a **workflow**, not a model. Numbered evals make it
cheap to compare runs and see whether a recipe / prompt / config
change actually moved the needle. Without this, every change becomes
a guess.
