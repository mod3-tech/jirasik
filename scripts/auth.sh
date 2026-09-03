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

# --- Persist a token ---
_save_token() {
  printf '%s\n' "$1" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE" 2>/dev/null || true
}

# --- Get session token ---
_load_token() {
  TOKEN=""
  if [[ -f "$TOKEN_FILE" ]]; then
    TOKEN=$(cat "$TOKEN_FILE")
    if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
      return
    fi
    TOKEN=""
  fi
  if [[ -f "$PROFILE_DIR/cookies.sqlite" ]]; then
    local sql="SELECT value FROM moz_cookies WHERE host LIKE '%atlassian%' AND name='tenant.session.token' LIMIT 1"
    if type -t _ff_safe_cookie_query &>/dev/null; then
      TOKEN=$(_ff_safe_cookie_query "$PROFILE_DIR" "$sql")
    else
      TOKEN=$(sqlite3 "$PROFILE_DIR/cookies.sqlite" "$sql")
    fi
    if [[ -n "$TOKEN" && "$TOKEN" != "null" ]]; then
      _save_token "$TOKEN"
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

_open_firefox() {
  if type -t _ff_open_profile &>/dev/null; then
    _ff_open_profile "$PROFILE_DIR" "$JIRA"
    return
  fi
  # Fallback if lib/firefox.sh could not be sourced. Scope the kill to our own
  # profile — never touch the user's personal Firefox session.
  pkill -f "firefox.*-profile ${PROFILE_DIR}" 2>/dev/null
  pkill -f "firefox.*--profile ${PROFILE_DIR}" 2>/dev/null
  sleep 1
  firefox -profile "$PROFILE_DIR" "$JIRA" &>/dev/null &
}

# --- Normalize a pasted cookie value ---
# Accepts a bare value, `tenant.session.token=VALUE`, a `a=1; b=2` cookie
# string, or any of those wrapped in quotes.
_normalize_pasted_token() {
  local raw="$1"
  raw="${raw#"${raw%%[![:space:]]*}"}"   # ltrim
  raw="${raw%"${raw##*[![:space:]]}"}"   # rtrim
  raw="${raw#[\"\']}"
  raw="${raw%[\"\']}"
  # If a full cookie string was pasted, pick out our cookie.
  if [[ "$raw" == *"tenant.session.token="* ]]; then
    raw="${raw#*tenant.session.token=}"
  fi
  raw="${raw%%;*}"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  raw="${raw#[\"\']}"
  raw="${raw%[\"\']}"
  printf '%s' "$raw"
}

_print_reauth_prompt() {
  {
    echo ""
    echo "  A) Log in to the Firefox window jirasik opened, then press Enter here."
    echo ""
    echo "  B) Or log in with your own browser (1Password, existing SSO session)"
    echo "     and paste the session cookie:"
    echo "       1. Open:  $JIRA"
    echo "       2. Log in, then open DevTools (F12)"
    echo "       3. Chrome/Edge: Application -> Cookies -> $JIRA"
    echo "          Firefox:     Storage     -> Cookies -> $JIRA"
    echo "          (the cookie is HttpOnly, so the console won't show it)"
    echo "       4. Copy the Value of  tenant.session.token"
    echo "       5. Paste it below, then press Enter"
    echo ""
    echo "  Enter = re-check Firefox   r = reopen Firefox   Ctrl-C = give up"
    printf "  > "
  } >&2
}

# --- Interactive re-auth: retry until it works or the user aborts ---
_interactive_reauth() {
  rm -f "$TOKEN_FILE"

  # Never prompt without a terminal — an agent or a piped caller would spin
  # forever on EOF. Emit the documented auth_failed shape instead.
  if [[ ! -t 0 ]]; then
    echo '{"error": "auth_failed", "status": 401, "message": "Session expired and no terminal is available to re-authenticate. Run any jirasik command from an interactive shell to log in."}' >&2
    return 1
  fi

  echo "Session expired. Opening Firefox to re-authenticate..." >&2
  _open_firefox

  trap 'echo "" >&2; echo "Aborted — still not authenticated." >&2; exit 130' INT

  local input
  while true; do
    _print_reauth_prompt
    if ! IFS= read -r input; then
      echo "" >&2
      echo "Input closed — still not authenticated." >&2
      trap - INT
      return 1
    fi
    input="$(_normalize_pasted_token "$input")"

    case "$input" in
      "")
        # Nothing pasted: re-read the cookie from jirasik's Firefox profile.
        _load_token
        ;;
      r | R)
        _open_firefox
        continue
        ;;
      *)
        TOKEN="$input"
        ;;
    esac

    if _validate_token; then
      _save_token "$TOKEN"
      echo "  ✓ Authenticated." >&2
      trap - INT
      return 0
    fi

    rm -f "$TOKEN_FILE"
    echo "  ✗ Still not authenticated. Log in again, or paste a fresh cookie value." >&2
  done
}

_load_token

if ! _validate_token; then
  _interactive_reauth || exit 1
fi

# --- Auth check helper — call after a curl request ---
# Usage: check_auth "$RESPONSE" ".fields" or check_auth "$RESPONSE" ".issues"
# Always exits: the in-flight response is unusable, so the caller must re-run.
check_auth() {
  local response="$1"
  local valid_key="$2"
  if echo "$response" | jq -e "$valid_key" > /dev/null 2>&1; then
    return 0
  fi
  if _interactive_reauth; then
    echo "Re-authenticated — please re-run the command." >&2
  fi
  exit 1
}
