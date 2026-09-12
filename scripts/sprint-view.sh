#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

# --- Fetch all sprint issues ---
# ORDER BY Rank ASC mirrors the manual top-to-bottom card order from Jira's
# board (the drag/drop "Rank" field). display-issues.sh then splits active vs.
# Done while preserving this rank order within each group.
RESPONSE=$("$JIRA_API" GET /search/jql --raw \
  --query 'jql=sprint in (openSprints()) ORDER BY Rank ASC' \
  --query fields=summary,status,assignee,customfield_10026,customfield_10021,customfield_10014 \
  --query maxResults=100)

# --- Pick a user ---
# Filter can be passed as an arg (all | me | unassigned | a display name) to
# skip the interactive picker, making this scriptable. Bare + TTY => gum prompt.
CURRENT_USER=$("$JIRA_API" GET /myself --raw | jq -r '.displayName // "Unknown"')

ARG="${1:-}"
if [[ -n "$ARG" ]]; then
  case "$(echo "$ARG" | tr '[:upper:]' '[:lower:]')" in
    all)        SELECTED="All users" ;;
    me)         SELECTED="$CURRENT_USER (me)" ;;
    unassigned) SELECTED="Unassigned" ;;
    *)          SELECTED="$ARG" ;;
  esac
else
  USERS=$(echo "$RESPONSE" | jq -r '[.issues[].fields.assignee.displayName // "Unassigned"] | unique | .[]' | sort)
  SELECTED=$(printf "All users\n%s\n%s" "$CURRENT_USER (me)" "$USERS" | awk '!seen[$0]++' | gum filter --header "Filter by:")
fi

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
