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
  echo ""
  echo "Output (tab-separated): <accountId>\\t<displayName>\\t<emailAddress>"
  exit 1
fi

# Use /user/search (singular) — /users/search returns unfiltered results
# on Jira Cloud regardless of query, breaking name/email lookup.
RESPONSE=$("$JIRA_API" GET /user/search --raw \
  --query "query=$QUERY" \
  --query maxResults=20)

echo "$RESPONSE" | jq -r '.[]
  | select((.accountType // "atlassian") == "atlassian")
  | select(.active != false)
  | [.accountId, .displayName, (.emailAddress // "")]
  | @tsv'
