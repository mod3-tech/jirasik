#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

# --- Parse argument ---
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo 'Usage: fetch_confluence.sh <CONFLUENCE-URL or PAGE-ID>'
  exit 1
fi

# --- Extract page ID ---
PAGE_ID=""

if [[ "$ARG" =~ ^[0-9]+$ ]]; then
  # Bare numeric page ID
  PAGE_ID="$ARG"

elif [[ "$ARG" == *"/wiki/x/"* ]] || [[ "$ARG" == */wiki/pages/tinyurl* ]]; then
  # Short link — follow redirects to resolve the page ID
  FINAL_URL=$(curl -sIL -b "tenant.session.token=$TOKEN" "$ARG" --max-time 15 \
    | grep -i "^location:" | tail -1 | tr -d '\r' | sed 's/^[Ll]ocation: *//')
  PAGE_ID=$(echo "$FINAL_URL" | grep -oE '/pages/([0-9]+)' | grep -oE '[0-9]+' || true)

elif [[ "$ARG" == *"/pages/"* ]]; then
  # Full page URL — extract ID directly
  PAGE_ID=$(echo "$ARG" | grep -oE '/pages/([0-9]+)' | grep -oE '[0-9]+' || true)
fi

if [[ -z "$PAGE_ID" ]]; then
  echo "Could not extract page ID from: $ARG"
  exit 1
fi

# --- Fetch page content ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/wiki/rest/api/content/$PAGE_ID?expand=body.storage,version,space" \
  --max-time 15)

check_auth "$RESPONSE" ".title"

# --- Extract metadata ---
TITLE=$(echo "$RESPONSE" | jq -r '.title // "Untitled"')
SPACE_KEY=$(echo "$RESPONSE" | jq -r '.space.key // "?"')
VERSION=$(echo "$RESPONSE" | jq -r '.version.number // "?"')
MODIFIED=$(echo "$RESPONSE" | jq -r '.version.when // ""' | cut -dT -f1)
URL="$JIRA/wiki/spaces/$SPACE_KEY/pages/$PAGE_ID"

# --- Extract and clean body ---
BODY=$(echo "$RESPONSE" | jq -r '.body.storage.value // ""')

# Unwrap CDATA sections and strip ac:plain-text-body tags
BODY=$(echo "$BODY" \
  | sed 's/<!\[CDATA\[//g; s/\]\]>//g' \
  | sed 's/<ac:plain-text-body>//g; s/<\/ac:plain-text-body>//g')

# --- Output ---
echo "Title: $TITLE"
echo "Space: $SPACE_KEY"
echo "Version: $VERSION"
echo "Modified: $MODIFIED"
echo "URL: $URL"
echo ""
echo "$BODY"
