#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"
source "$SCRIPT_DIR/lib/adf.sh"

BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'

# --- Parse argument ---
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo "Usage: comments.sh <TICKET-KEY or URL>"
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

# --- Fetch comments ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY/comment?orderBy=-created&maxResults=20")

check_auth "$RESPONSE" ".comments"

COUNT=$(echo "$RESPONSE" | jq '.comments | length')

if [[ "$COUNT" -eq 0 ]]; then
  echo ""
  echo "${DIM}No comments on ${TICKET_KEY}${RST}"
  echo ""
  exit 0
fi

TOTAL=$(echo "$RESPONSE" | jq '.total')

# --- Display ---
echo ""
echo "${BOLD}Comments on ${TICKET_KEY}${RST} ${DIM}(${COUNT} of ${TOTAL})${RST}"
echo ""

echo "$RESPONSE" | jq -c '.comments[]' | while IFS= read -r comment; do
  AUTHOR=$(echo "$comment" | jq -r '.author.displayName // "Unknown"')
  CREATED=$(echo "$comment" | jq -r '.created // ""')

  # Format date: 2024-01-15T10:30:00.000+0000 -> Jan 15, 2024 10:30
  if [[ -n "$CREATED" ]]; then
    DATE_FMT=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${CREATED%%.*}" "+%b %-d, %Y %H:%M" 2>/dev/null || echo "$CREATED")
  else
    DATE_FMT=""
  fi

  BODY=$(echo "$comment" | jq -r "$ADF_TO_MD_FILTER" 2>/dev/null)

  printf "  ${YELLOW}%s${RST} ${DIM}%s${RST}\n" "$AUTHOR" "$DATE_FMT"
  if [[ -n "$BODY" ]]; then
    echo "$BODY" | sed 's/^/    /'
  fi
  echo ""
done
