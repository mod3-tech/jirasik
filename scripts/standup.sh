#!/usr/bin/env bash
# What did I ship, grouped by day, across every git repo under a root dir.
# Git ground truth, annotated with each ticket's current Jira status/points.
# Usage: standup.sh [SINCE] [UNTIL]
#   dates are YYYY-MM-DD; default range is the last 7 days.
#   STANDUP_ROOT   dir to scan for repos (default ~/work/fullsteam)
#   STANDUP_AUTHOR git author to filter on  (default: git config user.name)
#   --no-jira      skip the Jira annotation (pure git, no auth)
# Commit subjects carry ticket keys (KEY-123 per branch/commit convention);
# those keys get a [status, Npts] tag. Jira unreachable => plain git + a note.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

JIRA=1
ARGS=()
for a in "$@"; do
  [[ "$a" == "--no-jira" ]] && { JIRA=0; continue; }
  ARGS+=("$a")
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

ROOT="${STANDUP_ROOT:-$HOME/work/fullsteam}"
AUTHOR="${STANDUP_AUTHOR:-$(git config user.name)}"
SINCE="${1:-$(date -v-7d +%F 2>/dev/null || date -d '7 days ago' +%F)}"
UNTIL="${2:-$(date +%F)}"

LINES=""
for repo in "$ROOT"/*/; do
  [ -e "$repo/.git" ] || continue
  LINES+=$(git -C "$repo" log --all --author="$AUTHOR" \
    --since="$SINCE 00:00" --until="$UNTIL 23:59" \
    --date=short --pretty=format:"%ad	$(basename "$repo")	%s" 2>/dev/null)
  LINES+=$'\n'
done
LINES=$(printf '%s' "$LINES" | grep -v '^$' | sort || true)

[ -z "$LINES" ] && exit 0

# Build a key -> "[status, Npts]" annotation map from one batch JQL lookup.
# Any failure (no keys, auth expired, offline) leaves the map empty and the
# git output prints unchanged, with a note.
ANNOT=""
NOTE=""
if [[ "$JIRA" -eq 1 ]]; then
  KEYS=$(printf '%s\n' "$LINES" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | sort -u || true)
  if [[ -n "$KEYS" ]]; then
    JQL="key in ($(printf '%s\n' "$KEYS" | paste -sd, -))"
    if JSON=$("$SCRIPT_DIR/search_issues.sh" --json "$JQL" \
                summary,status,customfield_10026 200 2>/dev/null); then
      # key<TAB>status<TAB>pts<TAB>statusCategory. Points floored so 5.0 -> 5.
      ANNOT=$(printf '%s' "$JSON" | jq -r '
        .issues[]? |
        (.fields.customfield_10026) as $p |
        (if $p == null then "" else ($p | floor | tostring) end) as $ps |
        "\(.key)\t\(.fields.status.name // "-")\t\($ps)\t\(.fields.status.statusCategory.key // "unknown")"' \
        2>/dev/null || true)
    else
      NOTE="(Jira unreachable - showing git only)"
    fi
  fi
fi

# ANNOT (key<TAB>status<TAB>pts, one per line) and the git LINES are fed as two
# streams so BSD awk never sees newlines inside a -v var. First stream = annot
# rows (3 fields), second = git lines (also 3 fields). Distinguish by a marker
# column prepended to the git lines.
source "$SCRIPT_DIR/lib/colors.sh"

{ [[ -n "$ANNOT" ]] && printf '%s\n' "$ANNOT"; printf '%s\n' "$LINES" | sed 's/^/GIT\t/'; } \
  | awk -F'\t' -v note="$NOTE" \
      -v dim="$DIM" -v rst="$RST" -v green="$GREEN" -v yellow="$YELLOW" \
      -v blue="$BLUE" -v purple="$PURPLE" '
  function status_clr(name, cat,   l) {
    l = tolower(name)
    if (cat == "done") return green
    if (l ~ /hold/) return yellow
    if (l ~ /review|await|wait|ready/) return purple
    if (cat == "indeterminate") return blue
    return rst
  }
  $1 != "GIT" { status[$1]=$2; pts[$1]=$3; cat[$1]=$4; next }
  { d=$2; r=$3; s=$4 }
  d != day  { day=d; repo=""; printf "\n## %s\n", d }
  r != repo { repo=r; printf "\n%s\n", r }
  {
    tag = ""
    if (match(s, /[A-Z][A-Z0-9]+-[0-9]+/)) {
      k = substr(s, RSTART, RLENGTH)
      if (k in status) {
        body = status[k]
        if (pts[k] != "") body = body ", " pts[k] "pts"
        tag = " " dim "[" rst status_clr(status[k], cat[k]) body rst dim "]" rst
      }
    }
    printf "- %s%s\n", s, tag
  }
  END { if (note != "") printf "\n%s\n", note }
'
