#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

QUERY="${1:-}"

if [[ -z "$QUERY" ]]; then
  echo "Usage: search_users.sh <SEARCH-QUERY>"
  echo "Example: search_users.sh john"
  exit 1
fi

RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/users/search?query=$QUERY&maxResults=20")

check_auth "$RESPONSE" ".[0]"

echo "$RESPONSE" | jq -r '.[] | select(.accountType == "atlassian") | "\(.displayName) |\(.emailAddress)"'