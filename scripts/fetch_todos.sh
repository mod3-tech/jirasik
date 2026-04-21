#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

# --- Fetch current user's sprint tickets ---
RESPONSE=$("$JIRA_API" GET /search/jql --raw \
  --query 'jql=assignee=currentUser() AND sprint in (openSprints()) ORDER BY statusCategory DESC, updated DESC' \
  --query fields=summary,status,customfield_10026,customfield_10021,customfield_10014 \
  --query maxResults=50)

# --- Display ---
SPRINT=$(echo "$RESPONSE" | jq -r '
  [.issues[].fields.customfield_10021[]? | select(.state == "active") | .name] | unique | first // "Unknown Sprint"
')

ISSUES="$RESPONSE"
TITLE="Todos for $(date "+%B %-d, %Y")"
SUBTITLE="$SPRINT"
source "$SCRIPT_DIR/display-issues.sh"
