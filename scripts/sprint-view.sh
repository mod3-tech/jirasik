#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

# --- Fetch all sprint issues ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/search/jql?jql=sprint%20in%20(openSprints())%20ORDER%20BY%20statusCategory%20DESC%2C%20updated%20DESC&fields=summary,status,assignee,customfield_10026,customfield_10021,customfield_10014&maxResults=100")

check_auth "$RESPONSE" ".issues"

# --- Pick a user ---
CURRENT_USER=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/myself" | jq -r '.displayName // "Unknown"')

USERS=$(echo "$RESPONSE" | jq -r '[.issues[].fields.assignee.displayName // "Unassigned"] | unique | .[]' | sort)

SELECTED=$(printf "All users\n%s\n%s" "$CURRENT_USER (me)" "$USERS" | awk '!seen[$0]++' | gum filter --header "Filter by:")

if [[ -z "$SELECTED" ]]; then
  exit 0
fi

# --- Filter issues ---
if [[ "$SELECTED" == "All users" ]]; then
  FILTERED="$RESPONSE"
elif [[ "$SELECTED" == *"(me)"* ]]; then
  FILTERED=$(echo "$RESPONSE" | jq --arg name "$CURRENT_USER" '{issues: [.issues[] | select(.fields.assignee.displayName == $name)]}')
elif [[ "$SELECTED" == "Unassigned" ]]; then
  FILTERED=$(echo "$RESPONSE" | jq '{issues: [.issues[] | select(.fields.assignee == null)]}')
else
  FILTERED=$(echo "$RESPONSE" | jq --arg name "$SELECTED" '{issues: [.issues[] | select(.fields.assignee.displayName == $name)]}')
fi

ISSUE_COUNT=$(echo "$FILTERED" | jq '.issues | length')
if [[ "$ISSUE_COUNT" -eq 0 ]]; then
  echo "No issues found."
  exit 0
fi

# --- Display ---
SPRINT=$(echo "$RESPONSE" | jq -r '
  [.issues[].fields.customfield_10021[]? | select(.state == "active") | .name] | unique | first // "Unknown Sprint"
')

ISSUES="$FILTERED"
TITLE="$SELECTED"
SUBTITLE="$SPRINT"
source "$SCRIPT_DIR/display-issues.sh"
