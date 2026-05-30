#!/usr/bin/env bash
# Verify that a Goose run produced real artifacts on GitHub.
#
# Checks:
#   1. Session log contains at least one tool call (▸ marker).
#   2. Remote has a branch goose/issue-N-*.
#   3. A PR closing #N exists (open or merged).
#
# Usage:
#   ./scripts/post-run-check.sh 28                          # use latest eval log
#   ./scripts/post-run-check.sh 28 evals/eval-02/goose-s.log
#
# Exit codes:
#   0  — PASS (tool calls + at least one of branch or PR)
#   1  — FAIL
set -euo pipefail

# ------- Arguments
ISSUE_NUMBER="${1:?Usage: $0 ISSUE_NUMBER [SESSION_LOG_PATH]}"
shift

SESSION_LOG_PATH=""
if [[ $# -ge 1 ]]; then
  SESSION_LOG_PATH="$1"
else
  # Default: most recently modified goose-session*.log under evals/*/
  SESSION_LOG_PATH=$(find evals -name 'goose-session*.log' -type f -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  if [[ -z "$SESSION_LOG_PATH" ]]; then
    echo "[CHECK 0] ERROR: no goose-session*.log found under evals/" >&2
    exit 1
  fi
fi

if [[ ! -f "$SESSION_LOG_PATH" ]]; then
  echo "[CHECK 0] ERROR: session log not found: $SESSION_LOG_PATH" >&2
  exit 1
fi

# ------- Resolve owner/repo for gh commands
GH_OWNER=""
GH_REPO=""
read -r GH_OWNER GH_REPO < <(gh repo view --json owner,name \
  | grep -oP '"(owner|name)": "(.+?)"' \
  | sed 's/"[^"]*": "//;s/"$//' | tr '\n' ' ')

if [[ -z "$GH_OWNER" || -z "$GH_REPO" ]]; then
  echo "ERROR: could not determine repo via 'gh repo view'" >&2
  exit 1
fi

# ------- CHECK 1 — Tool calls present in session log
TOOL_CALL_COUNT=$(grep -cE '^[[:space:]]*▸ ' "$SESSION_LOG_PATH" 2>/dev/null || true)
if [[ "$TOOL_CALL_COUNT" -ge 1 ]]; then
  echo "[CHECK 1] PASS — tool calls found: $TOOL_CALL_COUNT"
else
  echo "[CHECK 1] FAIL — tool calls found: $TOOL_CALL_COUNT"
fi

# ------- CHECK 2 — Branch on remote
BRANCH_NAME=""
BRANCH_LIST=$(gh api "repos/${GH_OWNER}/${GH_REPO}/branches" --jq '.[].name' 2>/dev/null || true)
while IFS= read -r b; do
  if [[ "$b" =~ ^goose/issue-${ISSUE_NUMBER}- ]]; then
    BRANCH_NAME="$b"
    break
  fi
done <<< "$BRANCH_LIST"

if [[ -n "$BRANCH_NAME" ]]; then
  echo "[CHECK 2] PASS — branch found: $BRANCH_NAME"
else
  echo "[CHECK 2] FAIL — no matching branch"
fi

# ------- CHECK 3 — PR closing the issue
CLOSED_PR=""
CLOSED_PR=$(gh pr list --state all --search "closes #${ISSUE_NUMBER} in:body" \
  --json number --jq '.[0].number' 2>/dev/null || true)

if [[ -n "$CLOSED_PR" ]]; then
  echo "[CHECK 3] PASS — PR found: #${CLOSED_PR}"
else
  echo "[CHECK 3] FAIL — no PR closing #${ISSUE_NUMBER}"
fi

# ------- Final result
# PASS if check 1 passes AND (check 2 OR check 3) passes
CHECK1_PASS=false
CHECK_BRANCH_PASS=false
CHECK_PR_PASS=false

if [[ "$TOOL_CALL_COUNT" -ge 1 ]]; then
  CHECK1_PASS=true
fi

if [[ -n "$BRANCH_NAME" ]]; then
  CHECK_BRANCH_PASS=true
fi

if [[ -n "$CLOSED_PR" ]]; then
  CHECK_PR_PASS=true
fi

if $CHECK1_PASS && ($CHECK_BRANCH_PASS || $CHECK_PR_PASS); then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
