#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

PROJECT_KEY="${1:-}"
if [[ -z "$PROJECT_KEY" ]]; then
  echo "Usage: get_issue_types.sh <PROJECT-KEY>"
  exit 1
fi

RESPONSE=$("$JIRA_API" GET "/project/$PROJECT_KEY" --raw)

echo "$RESPONSE" | jq -r '.issueTypes[] | "\(.name) (" + (if .subtask then "subtask" else "standard" end) + ")"' | sort
