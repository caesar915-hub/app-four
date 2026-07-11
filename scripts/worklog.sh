#!/usr/bin/env bash
# Generate a WORKLOG.md session block from git/gh primary sources.
# Usage:
#   scripts/worklog.sh                  # auto-detect range from WORKLOG.md
#   scripts/worklog.sh <since-ref>      # explicit lower bound (exclusive)
#   scripts/worklog.sh main..HEAD       # explicit git range
#
# Output: a Markdown block ready to prepend into docs/WORKLOG.md.
# The block is printed to stdout — pipe or redirect as needed.
# Append mode:  scripts/worklog.sh >> docs/WORKLOG.md  (don't — it goes at top)
# Prepend mode: { scripts/worklog.sh; tail -n +3 docs/WORKLOG.md; } > /tmp/wl && mv /tmp/wl docs/WORKLOG.md

set -euo pipefail

WORKLOG="${WORKLOG_FILE:-docs/WORKLOG.md}"
NOW=$(date '+%Y-%m-%d %H:%M')
BRANCH=$(git branch --show-current)

# ── Determine range ──────────────────────────────────────────────────────────

if [[ $# -ge 1 ]]; then
  if [[ "$1" == *".."* ]]; then
    RANGE="$1"
    SINCE_REF="${1%%\.\.*}"
  else
    SINCE_REF="$1"
    RANGE="${SINCE_REF}..HEAD"
  fi
else
  # Auto-detect: find the first 8+ hex hash in the latest block of WORKLOG.md.
  # The file has hashes like "`d28b611d`" or "  - `d28b611d`".
  FIRST_HASH=$(grep -oE '[0-9a-f]{8,}' "$WORKLOG" 2>/dev/null | head -1 || true)
  if [[ -z "$FIRST_HASH" ]]; then
    echo "ERROR: cannot auto-detect range — no commit hash found in $WORKLOG" >&2
    echo "Pass an explicit ref: $0 <since-ref>" >&2
    exit 1
  fi
  SINCE_REF="$FIRST_HASH"
  RANGE="${SINCE_REF}..HEAD"
fi

# Resolve to full hash for safety
SINCE_FULL=$(git rev-parse --verify "$SINCE_REF" 2>/dev/null || echo "$SINCE_REF")

# ── Gather commits ───────────────────────────────────────────────────────────

COMMITS=$(git log "$RANGE" --pretty=format:'%h|%ad|%s' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null)

if [[ -z "$COMMITS" ]]; then
  echo "No commits in range ${RANGE} — nothing to log." >&2
  exit 0
fi

# Oldest and newest timestamps in range
OLDEST_DATE=$(echo "$COMMITS" | tail -1 | cut -d'|' -f2)
NEWEST_DATE=$(echo "$COMMITS" | head -1 | cut -d'|' -f2)

# Topic: derive from first commit subject (strip prefix like "feat(x): ")
FIRST_SUBJECT=$(echo "$COMMITS" | head -1 | cut -d'|' -f3)
TOPIC=$(echo "$FIRST_SUBJECT" | sed 's/^[a-z]*([^)]*): //' | sed 's/^[a-z]*: //' | cut -c1-60)

# ── Group commits by conventional-commit type ────────────────────────────────

group_commits() {
  local pattern="$1"
  echo "$COMMITS" | grep -E "^\S+\|\S+ \S+\|${pattern}" || true
}

FEAT=$(echo "$COMMITS"    | grep -E '^\S+\|\S+ \S+\|feat'    || true)
FIX=$(echo "$COMMITS"     | grep -E '^\S+\|\S+ \S+\|fix'     || true)
TEST=$(echo "$COMMITS"    | grep -E '^\S+\|\S+ \S+\|test'    || true)
DOCS=$(echo "$COMMITS"    | grep -E '^\S+\|\S+ \S+\|docs'    || true)
CHORE=$(echo "$COMMITS"   | grep -E '^\S+\|\S+ \S+\|chore'   || true)
REFACTOR=$(echo "$COMMITS"| grep -E '^\S+\|\S+ \S+\|refactor'|| true)
MERGE=$(echo "$COMMITS"   | grep -E '^\S+\|\S+ \S+\|merge'   || true)
OTHER=$(echo "$COMMITS"   | grep -vE '^\S+\|\S+ \S+\|(feat|fix|test|docs|chore|refactor|merge)' || true)

format_group() {
  local label="$1"
  local rows="$2"
  [[ -z "$rows" ]] && return
  echo "- _${label}_"
  while IFS='|' read -r hash _ subject; do
    echo "  - \`${hash}\` ${subject}"
  done <<< "$rows"
}

# ── Gather git actions (merges + tags in range) ───────────────────────────────

MERGES=$(git log "$RANGE" --merges --pretty=format:'%h|%ad|%s' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null || true)
NEW_TAGS=$(git log "$RANGE" --decorate=full --pretty=format:'%D' 2>/dev/null \
  | grep -oE 'tag: [^,)]+' | sed 's/tag: //' | sort -u || true)

# ── Gather gh PR activity ─────────────────────────────────────────────────────

SINCE_ISO=$(git log -1 --pretty=format:'%aI' "$SINCE_FULL" 2>/dev/null || echo "1970-01-01T00:00:00Z")

gh_pr_row() {
  local num="$1" branch="$2" title="$3" state="$4"
  printf "- PR **#%s** \`%s\` — \"%s\" — %s\n" "$num" "$branch" "$title" "$state"
}

PR_OPENED=""
PR_MERGED=""

if command -v gh &>/dev/null; then
  # PRs opened after since date
  PR_OPENED=$(gh pr list --state all \
    --json number,title,headRefName,state,mergeable,createdAt,mergedAt \
    --limit 50 2>/dev/null \
    | jq -r --arg since "$SINCE_ISO" '
      .[] | select(.createdAt > $since) |
      "#\(.number)|\(.headRefName)|\(.title)|\(.state)/\(.mergeable // "?")"
    ' 2>/dev/null || true)

  PR_MERGED=$(gh pr list --state merged \
    --json number,title,headRefName,mergedAt \
    --limit 20 2>/dev/null \
    | jq -r --arg since "$SINCE_ISO" '
      .[] | select(.mergedAt != null and .mergedAt > $since) |
      "#\(.number)|\(.headRefName)|\(.title)|merged \(.mergedAt[:10])"
    ' 2>/dev/null || true)
fi

# ── Worktrees ─────────────────────────────────────────────────────────────────

WORKTREES=$(git worktree list 2>/dev/null || true)

# ── Emit block ───────────────────────────────────────────────────────────────

if [ "${OLDEST_DATE%% *}" = "${NEWEST_DATE%% *}" ]; then
  echo "## ${OLDEST_DATE%% *} ${OLDEST_DATE##* }–${NEWEST_DATE##* } · ${TOPIC} · ${BRANCH}"
else
  echo "## ${OLDEST_DATE} – ${NEWEST_DATE} · ${TOPIC} · ${BRANCH}"
fi
echo ""
echo "**Code changes**"

format_group "Major (feat)" "$FEAT"
format_group "Fixes" "$FIX"
format_group "Tests" "$TEST"
format_group "refactor" "$REFACTOR"
format_group "docs" "$DOCS"
format_group "chore" "$CHORE"
[[ -n "$OTHER" ]] && format_group "other" "$OTHER"

if [[ -n "$MERGES" ]] || [[ -n "$NEW_TAGS" ]]; then
  echo ""
  echo "**Git actions**"
  if [[ -n "$MERGES" ]]; then
    while IFS='|' read -r hash _ subject; do
      echo "- \`${hash}\` ${subject}"
    done <<< "$MERGES"
  fi
  if [[ -n "$NEW_TAGS" ]]; then
    while read -r tag; do
      echo "- tag \`${tag}\`"
    done <<< "$NEW_TAGS"
  fi
fi

if [[ -n "$PR_OPENED" ]] || [[ -n "$PR_MERGED" ]]; then
  echo ""
  echo "**gh actions**"
  if [[ -n "$PR_MERGED" ]]; then
    while IFS='|' read -r num branch title state; do
      echo "- PR ${num} merged \`${branch}\` — \"${title}\""
    done <<< "$PR_MERGED"
  fi
  if [[ -n "$PR_OPENED" ]]; then
    while IFS='|' read -r num branch title state; do
      echo "- PR ${num} opened \`${branch}\` — \"${title}\" — ${state}"
    done <<< "$PR_OPENED"
  fi
fi

echo ""
echo "**Worktrees**"
echo '```'
echo "$WORKTREES"
echo '```'

echo ""
echo "---"
