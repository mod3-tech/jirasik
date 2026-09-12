#!/usr/bin/env bash
# What did I ship, grouped by day, across every git repo under a root dir.
# Pure git, no Jira. Usage: standup.sh [SINCE] [UNTIL]
#   dates are YYYY-MM-DD; default range is the last 7 days.
#   STANDUP_ROOT   dir to scan for repos (default ~/work/fullsteam)
#   STANDUP_AUTHOR git author to filter on  (default: git config user.name)
set -euo pipefail

ROOT="${STANDUP_ROOT:-$HOME/work/fullsteam}"
AUTHOR="${STANDUP_AUTHOR:-$(git config user.name)}"
SINCE="${1:-$(date -v-7d +%F 2>/dev/null || date -d '7 days ago' +%F)}"
UNTIL="${2:-$(date +%F)}"

for repo in "$ROOT"/*/; do
  [ -e "$repo/.git" ] || continue
  git -C "$repo" log --all --author="$AUTHOR" \
    --since="$SINCE 00:00" --until="$UNTIL 23:59" \
    --date=short --pretty=format:"%ad	$(basename "$repo")	%s" 2>/dev/null
  echo
done | grep -v '^$' | sort | awk -F'\t' '
  $1 != day            { day=$1; repo=""; printf "\n## %s\n", $1 }
  $2 != repo           { repo=$2; printf "\n%s\n", $2 }
                       { printf "- %s\n", $3 }
'
