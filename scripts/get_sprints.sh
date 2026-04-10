#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

PROJECT_KEY="${1:-}"
if [[ -z "$PROJECT_KEY" ]]; then
  echo "Usage: get_sprints.sh <PROJECT-KEY>"
  exit 1
fi

# --- Find scrum boards for this project ---
BOARDS=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/agile/1.0/board?projectKeyOrId=$PROJECT_KEY&type=scrum&maxResults=50")

BOARD_COUNT=$(echo "$BOARDS" | jq '.values | length')

if [[ "$BOARD_COUNT" -eq 0 ]]; then
  echo "No scrum boards found for $PROJECT_KEY (project may use kanban)"
  exit 0
fi

# --- List sprints for each board ---
echo "$BOARDS" | jq -r '.values[] | "\(.id)\t\(.name)"' | while IFS=$'\t' read -r BOARD_ID BOARD_NAME; do
  SPRINTS=$(curl -sL -b "tenant.session.token=$TOKEN" \
    "$JIRA/rest/agile/1.0/board/$BOARD_ID/sprint?state=active,future&maxResults=10")

  SPRINT_COUNT=$(echo "$SPRINTS" | jq '.values | length')
  if [[ "$SPRINT_COUNT" -eq 0 ]]; then
    continue
  fi

  if [[ "$BOARD_COUNT" -gt 1 ]]; then
    echo "Board: $BOARD_NAME"
  fi

  echo "$SPRINTS" | jq -r '.values[] | "  \(.id)\t\(.state)\t\(.name)"'

  if [[ "$BOARD_COUNT" -gt 1 ]]; then
    echo ""
  fi
done
