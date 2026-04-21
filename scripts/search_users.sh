#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

QUERY="${1:-}"

if [[ -z "$QUERY" ]]; then
  echo "Usage: search_users.sh <SEARCH-QUERY>"
  echo "Example: search_users.sh john"
  exit 1
fi

RESPONSE=$("$JIRA_API" GET /users/search --raw \
  --query "query=$QUERY" \
  --query maxResults=20)

echo "$RESPONSE" | jq -r '.[] | select(.accountType == "atlassian") | "\(.displayName) |\(.emailAddress)"'
