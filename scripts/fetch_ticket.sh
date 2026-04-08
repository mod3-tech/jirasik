#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

EPIC_CACHE="$DIR/epic_cache.json"

# --- 0. Parse argument ---
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo '{"error": "no_argument", "message": "Usage: fetch_ticket.sh <TICKET-KEY or URL>"}'
  exit 1
fi

# Extract ticket key from URL or use as-is
if [[ "$ARG" == http* ]]; then
  TICKET_KEY=$(echo "$ARG" | grep -oE '[A-Z]+-[0-9]+' | head -1)
else
  TICKET_KEY="$ARG"
fi

if [[ -z "$TICKET_KEY" ]]; then
  echo '{"error": "bad_argument", "message": "Could not extract ticket key from: '"$ARG"'"}'
  exit 1
fi

# --- 1. Fetch ticket ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY?fields=summary,status,assignee,reporter,priority,customfield_10026,customfield_10021,customfield_10014,description,issuetype,parent")

check_auth "$RESPONSE" ".fields"

# --- 3. Resolve epic name ---
EPIC_KEY=$(echo "$RESPONSE" | jq -r '.fields.customfield_10014 // empty')
EPIC_NAME=""
if [[ -n "$EPIC_KEY" ]]; then
  if [[ -f "$EPIC_CACHE" ]]; then
    EPIC_NAME=$(jq -r --arg k "$EPIC_KEY" '.[$k] // empty' "$EPIC_CACHE")
  fi
  if [[ -z "$EPIC_NAME" ]]; then
    EPIC_NAME=$(curl -sL -b "tenant.session.token=$TOKEN" \
      "$JIRA/rest/api/3/issue/$EPIC_KEY?fields=summary" | jq -r '.fields.summary // "Unknown"')
    # Update cache
    if [[ -f "$EPIC_CACHE" ]]; then
      CACHE=$(cat "$EPIC_CACHE")
    else
      CACHE='{}'
    fi
    echo "$CACHE" | jq --arg k "$EPIC_KEY" --arg v "$EPIC_NAME" '. + {($k): $v}' > "$EPIC_CACHE"
  fi
fi

# --- 4. Format output ---
BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'

KEY=$(echo "$RESPONSE" | jq -r '.key')
TYPE=$(echo "$RESPONSE" | jq -r '.fields.issuetype.name // "Unknown"')
TITLE=$(echo "$RESPONSE" | jq -r '.fields.summary // "No title"')
STATUS=$(echo "$RESPONSE" | jq -r '.fields.status.name // "Unknown"')
ASSIGNEE=$(echo "$RESPONSE" | jq -r '.fields.assignee.displayName // "Unassigned"')
REPORTER=$(echo "$RESPONSE" | jq -r '.fields.reporter.displayName // "Unknown"')
PRIORITY=$(echo "$RESPONSE" | jq -r '.fields.priority.name // "None"')
POINTS=$(echo "$RESPONSE" | jq -r '.fields.customfield_10026 // empty')
PARENT_KEY=$(echo "$RESPONSE" | jq -r '.fields.parent.key // empty')
PARENT_SUMMARY=$(echo "$RESPONSE" | jq -r '.fields.parent.fields.summary // empty')

# Sprint (active)
SPRINT=$(echo "$RESPONSE" | jq -r '[.fields.customfield_10021[]? | select(.state == "active") | .name] | first // "None"')

# Slugified branch name
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
BRANCH="$KEY-$SLUG"

echo ""
echo "${BOLD}${KEY}${RST} ${DIM}(${TYPE})${RST}"
echo "${BOLD}${TITLE}${RST}"
echo ""
printf "  ${DIM}%-12s${RST} %s\n" "Status" "$STATUS"
printf "  ${DIM}%-12s${RST} %s\n" "Assignee" "$ASSIGNEE"
printf "  ${DIM}%-12s${RST} %s\n" "Reporter" "$REPORTER"
printf "  ${DIM}%-12s${RST} %s\n" "Priority" "$PRIORITY"
printf "  ${DIM}%-12s${RST} %s\n" "Sprint" "$SPRINT"
if [[ -n "$POINTS" ]]; then
  printf "  ${DIM}%-12s${RST} %s\n" "Points" "$POINTS"
fi
if [[ -n "$EPIC_KEY" ]]; then
  printf "  ${DIM}%-12s${RST} %s (%s)\n" "Epic" "$EPIC_NAME" "$EPIC_KEY"
fi
if [[ -n "$PARENT_KEY" ]]; then
  printf "  ${DIM}%-12s${RST} %s - %s\n" "Parent" "$PARENT_KEY" "$PARENT_SUMMARY"
fi
echo ""
printf "  ${DIM}%-12s${RST} ${CYAN}%s${RST}\n" "Branch" "$BRANCH"
printf "  ${DIM}%-12s${RST} ${CYAN}%s${RST}\n" "URL" "$JIRA/browse/$KEY"
echo ""

# --- 5. Description ---
DESC=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY?fields=description" | jq -r '
    [
      .. | select(type == "object" and .type == "text") | .text
    ] | join(" ")
  ' 2>/dev/null)

if [[ -n "$DESC" ]]; then
  echo "${DIM}--- Description ---${RST}"
  echo "$DESC" | glow
  echo ""
fi
