#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'

# --- 1. Get ticket key ---
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo "Usage: transition.sh <TICKET-KEY> [TRANSITION-NAME]"
  exit 1
fi

if [[ "$ARG" == http* ]]; then
  TICKET_KEY=$(echo "$ARG" | grep -oE '[A-Z]+-[0-9]+' | head -1)
else
  TICKET_KEY="$ARG"
fi

if [[ -z "$TICKET_KEY" ]]; then
  echo "Could not extract ticket key from: $ARG"
  exit 1
fi

TARGET="${2:-}"

# --- 2. Fetch current status ---
ISSUE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY?fields=summary,status")
check_auth "$ISSUE" ".fields"

SUMMARY=$(echo "$ISSUE" | jq -r '.fields.summary // "Unknown"')
STATUS=$(echo "$ISSUE" | jq -r '.fields.status.name // "Unknown"')

echo ""
echo "${BOLD}${TICKET_KEY}${RST} ${SUMMARY}"
echo "${DIM}Status:${RST} ${YELLOW}${STATUS}${RST}"

# --- Helper: fetch transitions and execute one by name ---
do_transition() {
  local target="$1"

  TRANSITIONS=$(curl -sL -b "tenant.session.token=$TOKEN" \
    "$JIRA/rest/api/3/issue/$TICKET_KEY/transitions")

  TRANSITION_ID=$(echo "$TRANSITIONS" | jq -r --arg name "$target" \
    '.transitions[] | select(.name == $name) | .id')

  if [[ -z "$TRANSITION_ID" ]]; then
    echo "No transition named: $target"
    echo "Available: $(echo "$TRANSITIONS" | jq -r '[.transitions[].name] | join(", ")')"
    return 1
  fi

  HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" \
    -b "tenant.session.token=$TOKEN" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"transition\":{\"id\":\"$TRANSITION_ID\"}}" \
    "$JIRA/rest/api/3/issue/$TICKET_KEY/transitions")

  if [[ "$HTTP_CODE" == "204" ]]; then
    NEW_STATUS=$(curl -sL -b "tenant.session.token=$TOKEN" \
      "$JIRA/rest/api/3/issue/$TICKET_KEY?fields=status" | jq -r '.fields.status.name // "Unknown"')
    echo "${GREEN}Moved${RST} ${YELLOW}${STATUS}${RST} ${DIM}→${RST} ${GREEN}${NEW_STATUS}${RST}"
    STATUS="$NEW_STATUS"
  else
    echo "Transition failed (HTTP $HTTP_CODE)"
    return 1
  fi
}

# --- 3a. Direct mode: transition name provided ---
if [[ -n "$TARGET" ]]; then
  do_transition "$TARGET"
  exit $?
fi

# --- 3b. Non-interactive: no TTY, just list transitions ---
if [[ ! -t 1 ]]; then
  TRANSITIONS=$(curl -sL -b "tenant.session.token=$TOKEN" \
    "$JIRA/rest/api/3/issue/$TICKET_KEY/transitions")
  echo ""
  echo "Available transitions:"
  echo "$TRANSITIONS" | jq -r '.transitions[].name' | while read -r name; do
    echo "  - $name"
  done
  exit 0
fi

# --- 3c. Interactive mode: gum choose loop ---
while true; do
  TRANSITIONS=$(curl -sL -b "tenant.session.token=$TOKEN" \
    "$JIRA/rest/api/3/issue/$TICKET_KEY/transitions")

  NAMES=$(echo "$TRANSITIONS" | jq -r '.transitions[].name')

  if [[ -z "$NAMES" ]]; then
    echo "${DIM}No transitions available.${RST}"
    break
  fi

  PICK=$(printf "%s\n← Exit" "$NAMES" | gum choose --header "Move to:")

  if [[ -z "$PICK" || "$PICK" == "← Exit" ]]; then
    break
  fi

  do_transition "$PICK"
done
