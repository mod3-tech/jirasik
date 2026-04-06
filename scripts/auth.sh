#!/usr/bin/env bash
# Shared auth helper — sourced by other scripts

DIR="$HOME/.jirasik"
mkdir -p "$DIR"
TOKEN_FILE="$DIR/session_token"

# --- Load config ---
CONFIG="$DIR/config"
if [[ -f "$CONFIG" ]]; then
  source "$CONFIG"
fi
JIRA="${JIRA_URL:-}"
if [[ -z "$JIRA" ]]; then
  echo '{"error": "no_config", "message": "Missing JIRA_URL. Run setup.sh."}'
  exit 1
fi

# --- Get session token ---
_load_token() {
  if [[ -f "$DIR/cookies.sqlite" ]]; then
    TOKEN=$(sqlite3 "$DIR/cookies.sqlite" \
      "SELECT value FROM moz_cookies WHERE host LIKE '%atlassian%' AND name='tenant.session.token' LIMIT 1")
    if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
      echo "$TOKEN" > "$TOKEN_FILE"
    else
      TOKEN=""
    fi
  fi
}

_load_token

if [[ -z "$TOKEN" ]]; then
  echo "Session expired. Opening Firefox to re-authenticate..." >&2
  open -a Firefox --args -profile "$DIR" "$JIRA"
  echo "Log in, then close Firefox and re-run the command." >&2
  exit 1
fi

# --- Auth check helper — call after a curl request ---
# Usage: check_auth "$RESPONSE" ".fields" or check_auth "$RESPONSE" ".issues"
check_auth() {
  local response="$1"
  local valid_key="$2"
  if echo "$response" | jq -e "$valid_key" > /dev/null 2>&1; then
    return 0
  fi
  rm -f "$TOKEN_FILE"
  echo "Session expired. Opening Firefox to re-authenticate..." >&2
  open -a Firefox --args -profile "$DIR" "$JIRA"
  echo "Log in, then close Firefox and re-run the command." >&2
  exit 1
}
