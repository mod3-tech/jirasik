#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

PROJECT_KEY="${1:-}"
if [[ -z "$PROJECT_KEY" ]]; then
  echo "Usage: get_issue_types.sh <PROJECT-KEY>"
  exit 1
fi

RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/project/$PROJECT_KEY")

check_auth "$RESPONSE" "."

echo "$RESPONSE" | jq -r '.issueTypes[] | "\(.name) (\(.subtask == true ? "subtask" : "standard"))"' | sort