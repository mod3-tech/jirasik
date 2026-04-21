#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'

# --- Parse arguments ---
ARG="${1:-}"
COMMENT_TEXT="${2:-}"

if [[ -z "$ARG" ]]; then
  echo "Usage: add_comment.sh <TICKET-KEY> [COMMENT]"
  echo "  If COMMENT is omitted, opens an interactive editor."
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

# --- Get comment text ---
if [[ -z "$COMMENT_TEXT" ]]; then
  if [[ -t 0 ]]; then
    # Interactive: use gum
    COMMENT_TEXT=$(gum write --header "Comment on $TICKET_KEY" --placeholder "Type your comment...")
  else
    # Piped input
    COMMENT_TEXT=$(cat)
  fi
fi

if [[ -z "$COMMENT_TEXT" ]]; then
  echo "${DIM}Empty comment, nothing to post.${RST}"
  exit 0
fi

# --- Build ADF payload ---
# Split text on newlines into separate paragraphs
CONTENT=$(echo "$COMMENT_TEXT" | jq -Rs '
  split("\n")
  | map(select(. != ""))
  | map({type: "paragraph", content: [{type: "text", text: .}]})
')

PAYLOAD=$(jq -n --argjson content "$CONTENT" '{
  body: {
    type: "doc",
    version: 1,
    content: $content
  }
}')

# --- Post comment ---
if "$JIRA_API" POST "/issue/$TICKET_KEY/comment" --data "$PAYLOAD" >/dev/null; then
  echo ""
  echo "${GREEN}Comment added${RST} to ${BOLD}${TICKET_KEY}${RST}"
else
  echo "Failed to add comment"
  exit 1
fi
