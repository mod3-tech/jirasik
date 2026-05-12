#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

source "$SCRIPT_DIR/lib/colors.sh"

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
ISSUE=$("$JIRA_API" GET "/issue/$TICKET_KEY" --raw --query fields=summary,status)

SUMMARY=$(echo "$ISSUE" | jq -r '.fields.summary // "Unknown"')
STATUS=$(echo "$ISSUE" | jq -r '.fields.status.name // "Unknown"')

echo ""
echo "${BOLD}${TICKET_KEY}${RST} ${SUMMARY}"
echo "${DIM}Status:${RST} ${YELLOW}${STATUS}${RST}"

# --- Helper: fetch transitions and execute one by name ---
do_transition() {
  local target="$1"

  local transitions
  transitions=$("$JIRA_API" GET "/issue/$TICKET_KEY/transitions" --raw)

  local transition_id
  transition_id=$(echo "$transitions" | jq -r --arg name "$target" \
    '.transitions[] | select(.name == $name) | .id')

  if [[ -z "$transition_id" ]]; then
    echo "No transition named: $target"
    echo "Available: $(echo "$transitions" | jq -r '[.transitions[].name] | join(", ")')"
    return 1
  fi

  local payload
  payload=$(jq -cn --arg id "$transition_id" '{transition: {id: $id}}')

  if "$JIRA_API" POST "/issue/$TICKET_KEY/transitions" --data "$payload" >/dev/null; then
    local new_status
    new_status=$("$JIRA_API" GET "/issue/$TICKET_KEY" --raw --query fields=status \
      | jq -r '.fields.status.name // "Unknown"')
    echo "${GREEN}Moved${RST} ${YELLOW}${STATUS}${RST} ${DIM}→${RST} ${GREEN}${new_status}${RST}"
    STATUS="$new_status"
  else
    echo "Transition failed"
    return 1
  fi
}

# --- 3a. Direct mode: transition name provided ---
if [[ -n "$TARGET" ]]; then
  if do_transition "$TARGET"; then
    exit 0
  else
    exit 1
  fi
fi

# --- 3b. Non-interactive: no TTY, just list transitions ---
if [[ ! -t 1 ]]; then
  TRANSITIONS=$("$JIRA_API" GET "/issue/$TICKET_KEY/transitions" --raw)
  echo ""
  echo "Available transitions:"
  echo "$TRANSITIONS" | jq -r '.transitions[].name' | while read -r name; do
    echo "  - $name"
  done
  exit 0
fi

# --- 3c. Interactive mode: gum choose loop ---
while true; do
  TRANSITIONS=$("$JIRA_API" GET "/issue/$TICKET_KEY/transitions" --raw)

  NAMES=$(echo "$TRANSITIONS" | jq -r '.transitions[].name')

  if [[ -z "$NAMES" ]]; then
    echo "${DIM}No transitions available.${RST}"
    break
  fi

  PICK=$(printf "%s\n← Exit" "$NAMES" | gum choose --header "Move to:")

  if [[ -z "$PICK" || "$PICK" == "← Exit" ]]; then
    break
  fi

  do_transition "$PICK" || true
done
