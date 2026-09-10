#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

QUERY="${1:-}"

SPACES=$("$JIRA_API" GET /space --wiki --raw \
  --query limit=250 \
  --query "spaceType=global")

if [[ -n "$QUERY" ]]; then
  echo "$SPACES" | jq -r --arg q "$QUERY" '
    [ .results[] | select((.name // "") | ascii_downcase | contains($q | ascii_downcase)) ]
    | sort_by(.name)[]
    | "\(.key)\t\(.name)"'
else
  echo "$SPACES" | jq -r '.results | sort_by(.name)[] | "\(.key)\t\(.name)"'
fi
