#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

QUERY="${1:-}"

FIELDS=$("$JIRA_API" GET /field --raw)

if [[ -n "$QUERY" ]]; then
  echo "$FIELDS" | jq -r --arg q "$QUERY" '
    [ .[]
      | select((.name // "") | ascii_downcase | contains($q | ascii_downcase))
      | {id, name, type: (.schema.type // "")}
    ]
    | sort_by(.name)[]
    | "\(.id)\t\(.type)\t\(.name)"'
else
  echo "$FIELDS" | jq -r '.[] | "\(.id)\t\(.schema.type // "")\t\(.name)"' | sort
fi
