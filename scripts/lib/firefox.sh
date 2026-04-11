#!/usr/bin/env bash
# Firefox helpers — sourced by auth.sh, setup.sh, bin/jirasik
# Provides: FIREFOX_BIN, _ff_find, _ff_kill_profile, _ff_open_profile,
#           _ff_init_profile, _ff_safe_cookie_query, _ff_profile_ok

# --- Locate Firefox binary ---
# Sets FIREFOX_BIN to the first working path found.
_ff_find() {
  if [[ -n "${FIREFOX_BIN:-}" ]]; then
    return 0
  fi

  # Check PATH first (covers Linux, Homebrew-linked, etc.)
  if command -v firefox &>/dev/null; then
    FIREFOX_BIN="firefox"
    return 0
  fi

  # macOS app bundle locations (stock install + Homebrew cask)
  local candidates=(
    "/Applications/Firefox.app/Contents/MacOS/firefox"
    "$HOME/Applications/Firefox.app/Contents/MacOS/firefox"
    "/opt/homebrew/bin/firefox"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      FIREFOX_BIN="$candidate"
      return 0
    fi
  done

  return 1
}

# --- Kill only jirasik's profile Firefox instance ---
# Matches processes running with our specific profile directory.
_ff_kill_profile() {
  local profile_dir="${1:?_ff_kill_profile requires profile_dir}"
  local pids
  # Match any firefox process whose command line includes our profile path
  pids=$(pgrep -f "firefox.*-profile ${profile_dir}" 2>/dev/null || true)
  if [[ -z "$pids" ]]; then
    # Also try without space after -profile (some invocations)
    pids=$(pgrep -f "firefox.*--profile ${profile_dir}" 2>/dev/null || true)
  fi
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill 2>/dev/null || true
    sleep 1
    # Force-kill any survivors
    echo "$pids" | xargs kill -9 2>/dev/null || true
  fi
}

# --- Open Firefox with jirasik profile ---
_ff_open_profile() {
  local profile_dir="${1:?_ff_open_profile requires profile_dir}"
  local url="${2:-}"
  _ff_find || { echo "Firefox not found" >&2; return 1; }
  _ff_kill_profile "$profile_dir"
  sleep 1
  if [[ -n "$url" ]]; then
    "$FIREFOX_BIN" -profile "$profile_dir" "$url" &>/dev/null &
  else
    "$FIREFOX_BIN" -profile "$profile_dir" &>/dev/null &
  fi
}

# --- Initialize a fresh Firefox profile ---
# Two-phase approach (see git history: 8e3e7b0 -> b2356be):
#   1. -CreateProfile: registers a named profile and initializes the directory.
#      This is the ONLY method that works reliably on older Firefox versions.
#   2. --profile --headless fallback: for newer systems where -CreateProfile
#      may not produce times.json but direct headless invocation does.
_ff_init_profile() {
  local profile_dir="${1:?_ff_init_profile requires profile_dir}"
  _ff_find || { echo "Firefox not found" >&2; return 1; }

  # Already initialized?
  if [[ -f "$profile_dir/times.json" ]]; then
    return 0
  fi

  mkdir -p "$profile_dir"

  # Phase 1: -CreateProfile (primary — required for older Firefox)
  "$FIREFOX_BIN" -CreateProfile "jirasik $profile_dir" --headless --screenshot /dev/null 2>/dev/null

  # Phase 2: --profile --headless fallback
  if [[ ! -f "$profile_dir/times.json" ]]; then
    rm -rf "$profile_dir"/*
    "$FIREFOX_BIN" --headless --profile "$profile_dir" about:blank 2>/dev/null &
    local pid=$!

    # Wait up to 10 seconds for the profile to initialize
    local waited=0
    while [[ $waited -lt 10 ]]; do
      if [[ -f "$profile_dir/times.json" ]]; then
        break
      fi
      sleep 1
      waited=$((waited + 1))
    done

    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  fi

  # Verify
  if [[ ! -f "$profile_dir/times.json" ]]; then
    return 1
  fi
  return 0
}

# --- Check profile health ---
# Returns 0 if the profile looks usable, 1 otherwise.
_ff_profile_ok() {
  local profile_dir="${1:?_ff_profile_ok requires profile_dir}"

  # Must have the sentinel file
  if [[ ! -f "$profile_dir/times.json" ]]; then
    return 1
  fi

  # If cookies.sqlite exists, it must be a valid SQLite DB
  if [[ -f "$profile_dir/cookies.sqlite" ]]; then
    if ! sqlite3 "$profile_dir/cookies.sqlite" "SELECT 1 FROM sqlite_master LIMIT 1" 2>/dev/null; then
      return 1
    fi
  fi

  return 0
}

# --- Safely query cookies.sqlite ---
# Firefox uses WAL mode. If Firefox is running, the DB may be locked or the
# WAL file may contain uncommitted data. We copy the DB + WAL + SHM to a
# temp directory and query the copy.
_ff_safe_cookie_query() {
  local profile_dir="${1:?_ff_safe_cookie_query requires profile_dir}"
  local sql="${2:?_ff_safe_cookie_query requires sql}"

  local db="$profile_dir/cookies.sqlite"
  if [[ ! -f "$db" ]]; then
    return 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  # Copy the DB and any WAL/SHM files atomically
  cp "$db" "$tmpdir/cookies.sqlite"
  [[ -f "$db-wal" ]] && cp "$db-wal" "$tmpdir/cookies.sqlite-wal"
  [[ -f "$db-shm" ]] && cp "$db-shm" "$tmpdir/cookies.sqlite-shm"

  sqlite3 "$tmpdir/cookies.sqlite" "$sql" 2>/dev/null
}
