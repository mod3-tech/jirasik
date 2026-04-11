#!/usr/bin/env bash
# Shared auth helper — sourced by other scripts

DIR="${DIR:-$HOME/.jirasik}"
PROFILE_DIR="$DIR/firefox-profile"
mkdir -p "$DIR" "$PROFILE_DIR"
TOKEN_FILE="$DIR/session_token"

# Source Firefox helper library (resolve from script's own location or DIR)
_AUTH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_AUTH_SCRIPT_DIR/lib/firefox.sh" ]]; then
  source "$_AUTH_SCRIPT_DIR/lib/firefox.sh"
elif [[ -f "$DIR/scripts/lib/firefox.sh" ]]; then
  source "$DIR/scripts/lib/firefox.sh"
fi

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
  if [[ -f "$TOKEN_FILE" ]]; then
    TOKEN=$(cat "$TOKEN_FILE")
    if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
      return
    fi
  fi
  if [[ -f "$PROFILE_DIR/cookies.sqlite" ]]; then
    local sql="SELECT value FROM moz_cookies WHERE host LIKE '%atlassian%' AND name='tenant.session.token' LIMIT 1"
    if type -t _ff_safe_cookie_query &>/dev/null; then
      TOKEN=$(_ff_safe_cookie_query "$PROFILE_DIR" "$sql")
    else
      TOKEN=$(sqlite3 "$PROFILE_DIR/cookies.sqlite" "$sql")
    fi
    if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
      echo "$TOKEN" > "$TOKEN_FILE"
    else
      TOKEN=""
    fi
  fi
}

_validate_token() {
  if [[ -z "$TOKEN" ]]; then
    return 1
  fi
  local resp
  resp=$(curl -sL -b "tenant.session.token=$TOKEN" "$JIRA/rest/api/3/myself" --max-time 10)
  if echo "$resp" | jq -e '.accountId' > /dev/null 2>&1; then
    return 0
  fi
  return 1
}

_reauth() {
  rm -f "$TOKEN_FILE"
  echo "Session expired. Opening Firefox to re-authenticate..." >&2
  if type -t _ff_open_profile &>/dev/null; then
    _ff_open_profile "$PROFILE_DIR" "$JIRA"
  else
    pkill -f "[Ff]irefox" 2>/dev/null
    sleep 1
    firefox -profile "$PROFILE_DIR" "$JIRA" &>/dev/null &
  fi
  echo "Log in, then close Firefox and press Enter to continue." >&2
  read -r
}

_load_token

if ! _validate_token; then
  _reauth
  _load_token
  if ! _validate_token; then
    echo "Failed to validate session. Please try again." >&2
    exit 1
  fi
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
  if type -t _ff_open_profile &>/dev/null; then
    _ff_open_profile "$PROFILE_DIR" "$JIRA"
  else
    pkill -f "[Ff]irefox" 2>/dev/null
    sleep 1
    firefox -profile "$PROFILE_DIR" "$JIRA" &>/dev/null &
  fi
  echo "Log in, then close Firefox and press Enter to continue." >&2
  read -r
  exit 1
}
