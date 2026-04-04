#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

# --- Fetch current user's sprint tickets ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/search/jql?jql=assignee%3DcurrentUser()%20AND%20sprint%20in%20(openSprints())%20ORDER%20BY%20statusCategory%20DESC%2C%20updated%20DESC&fields=summary,status,customfield_10026,customfield_10021,customfield_10014&maxResults=50")

check_auth "$RESPONSE" ".issues"

# --- Display ---
SPRINT=$(echo "$RESPONSE" | jq -r '
  [.issues[].fields.customfield_10021[]? | select(.state == "active") | .name] | unique | first // "Unknown Sprint"
')

ISSUES="$RESPONSE"
TITLE="Todos for $(date "+%B %-d, %Y")"
SUBTITLE="$SPRINT"
source "$SCRIPT_DIR/display-issues.sh"
