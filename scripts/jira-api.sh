#!/usr/bin/env bash
# jira-api.sh — generic authenticated Jira/Confluence/Agile API wrapper.
#
# Makes an HTTP call to the configured Jira instance using the Firefox
# session cookie loaded by auth.sh. Handles URL construction, query-string
# encoding, JSON body passing (inline, file, or stdin), HTTP status
# classification, and auth-failure detection — so commands and other
# scripts don't need to hand-roll curl.
#
# USAGE
#   jira-api.sh <METHOD> <PATH> [options]
#
# METHOD    GET | POST | PUT | PATCH | DELETE
# PATH      API path. Relative paths are rooted at the configured JIRA_URL
#           plus the base selected by --agile/--wiki (default: /rest/api/3).
#           Absolute paths beginning with /rest or /wiki are used as-is.
#
# OPTIONS
#   --data <JSON>         Inline JSON request body.
#   --data-file <PATH>    Read JSON body from file. Use '-' or '@-' for stdin.
#   --query KEY=VALUE     URL query parameter (repeatable, properly encoded).
#   --agile               Use /rest/agile/1.0 as the base instead of /rest/api/3.
#   --wiki                Use /wiki/rest/api as the base (Confluence).
#   --raw                 Do not pretty-print the response body (default: jq .).
#   -h, --help            Show this help.
#
# OUTPUT
#   On success: response body on stdout (pretty-printed unless --raw). Exit 0.
#   On error:   JSON error object on stderr, non-zero exit.
#
# ERROR SHAPES (stderr, one-line JSON — matches auth.sh / jira.md conventions)
#   {"error":"no_config", ...}                      exit 10  (from auth.sh)
#   {"error":"auth_failed", ...}                    exit 2   (401/403 or session)
#   {"error":"not_found", "path":"...", ...}        exit 3   (404)
#   {"error":"http_client", "status":4xx, ...}      exit 4   (other 4xx)
#   {"error":"http_server", "status":5xx, ...}      exit 5   (5xx)
#   {"error":"removed_endpoint", ...}               exit 6   (legacy /search)
#   {"error":"bad_usage", "message":"..."}          exit 64  (argument errors)
#
# EXAMPLES
#   jira-api.sh GET /issue/PROG-123
#   jira-api.sh GET /issue/PROG-123 --query fields=summary,status
#   jira-api.sh GET /search/jql --query jql='project=PROG' --query fields=summary
#   jira-api.sh POST /issue/PROG-123/comment --data-file body.json
#   echo "$PAYLOAD" | jira-api.sh POST /issue --data-file -
#   jira-api.sh PUT /issue/PROG-123 --data '{"fields":{"customfield_10026":5}}'
#   jira-api.sh GET /board --agile --query projectKeyOrId=PROG --query type=scrum
#   jira-api.sh GET /content/12345 --wiki --query expand=body.storage

set -euo pipefail

_emit_error() {
  # _emit_error <exit_code> <error_key> [<jq key=value>...]
  local code="$1"; shift
  local err="$1"; shift
  local jq_args=(-cn --arg error "$err")
  local filter='{error: $error'
  local i=0
  while (( $# >= 2 )); do
    local k="$1" v="$2"; shift 2
    # Try to preserve numeric status codes as numbers.
    if [[ "$k" == "status" && "$v" =~ ^[0-9]+$ ]]; then
      jq_args+=(--argjson "kv${i}" "$v")
    else
      jq_args+=(--arg "kv${i}" "$v")
    fi
    filter+=", ${k}: \$kv${i}"
    i=$((i+1))
  done
  filter+='}'
  jq "${jq_args[@]}" "$filter" >&2
  exit "$code"
}

_print_help() {
  # Extract the leading '#' comment banner (skip shebang, stop at blank line).
  awk 'NR==1 && /^#!/ { next } /^$/ { exit } /^#/ { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

# ─── Argument parsing ────────────────────────────────────────────────────

METHOD=""
API_PATH=""
DATA=""
DATA_FILE=""
HAVE_BODY=0
BASE_KIND="api3"   # api3 | agile | wiki
RAW=0
QUERY_KEYS=()
QUERY_VALS=()

if [[ $# -eq 0 ]]; then
  _print_help >&2
  _emit_error 64 "bad_usage" message "missing METHOD and PATH"
fi

# First two positionals: METHOD and PATH (if they don't look like options).
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  _print_help
  exit 0
fi

METHOD="${1:-}"; shift || true
API_PATH="${1:-}"; shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data)
      [[ $# -ge 2 ]] || _emit_error 64 "bad_usage" message "--data requires a value"
      DATA="$2"; HAVE_BODY=1; shift 2 ;;
    --data-file)
      [[ $# -ge 2 ]] || _emit_error 64 "bad_usage" message "--data-file requires a path"
      DATA_FILE="$2"; HAVE_BODY=1; shift 2 ;;
    --query)
      [[ $# -ge 2 ]] || _emit_error 64 "bad_usage" message "--query requires KEY=VALUE"
      local_kv="$2"
      if [[ "$local_kv" != *"="* ]]; then
        _emit_error 64 "bad_usage" message "--query must be KEY=VALUE, got: $local_kv"
      fi
      QUERY_KEYS+=("${local_kv%%=*}")
      QUERY_VALS+=("${local_kv#*=}")
      shift 2 ;;
    --agile) BASE_KIND="agile"; shift ;;
    --wiki)  BASE_KIND="wiki";  shift ;;
    --raw)   RAW=1; shift ;;
    -h|--help) _print_help; exit 0 ;;
    *) _emit_error 64 "bad_usage" message "unknown argument: $1" ;;
  esac
done

# ─── Validate ────────────────────────────────────────────────────────────

if [[ -z "$METHOD" ]]; then
  _emit_error 64 "bad_usage" message "missing METHOD"
fi
if [[ -z "$API_PATH" ]]; then
  _emit_error 64 "bad_usage" message "missing PATH"
fi

METHOD="$(echo "$METHOD" | tr '[:lower:]' '[:upper:]')"
case "$METHOD" in
  GET|POST|PUT|PATCH|DELETE) ;;
  *) _emit_error 64 "bad_usage" message "unsupported METHOD: $METHOD" ;;
esac

# Guard against the removed legacy JQL search endpoint (CHANGE-2046).
# Match /rest/api/3/search or /search but NOT /search/jql.
_path_no_query="${API_PATH%%\?*}"
if [[ "$_path_no_query" == "/rest/api/3/search" || "$_path_no_query" == "/search" ]]; then
  _emit_error 6 "removed_endpoint" \
    message "/rest/api/3/search was removed by Atlassian (CHANGE-2046). Use /search/jql instead." \
    path "$API_PATH"
fi

# ─── URL construction ────────────────────────────────────────────────────

# Bootstrap auth unless explicitly skipped (for tests).
if [[ "${JIRASIK_SKIP_AUTH_BOOTSTRAP:-0}" != "1" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/auth.sh"
fi

: "${JIRA:?JIRA base URL not set}"

_build_url() {
  local path="$1"
  # Absolute paths that already include the API prefix: keep as-is.
  if [[ "$path" == /rest/* || "$path" == /wiki/* ]]; then
    printf '%s%s' "$JIRA" "$path"
    return
  fi
  # Ensure leading slash.
  [[ "$path" == /* ]] || path="/$path"
  local base=""
  case "$BASE_KIND" in
    api3)  base="/rest/api/3" ;;
    agile) base="/rest/agile/1.0" ;;
    wiki)  base="/wiki/rest/api" ;;
  esac
  printf '%s%s%s' "$JIRA" "$base" "$path"
}

URL="$(_build_url "$API_PATH")"

# ─── Body resolution ─────────────────────────────────────────────────────

BODY=""
if [[ -n "$DATA_FILE" ]]; then
  if [[ "$DATA_FILE" == "-" || "$DATA_FILE" == "@-" ]]; then
    BODY="$(cat)"
  else
    [[ -f "$DATA_FILE" ]] || _emit_error 64 "bad_usage" message "data file not found: $DATA_FILE"
    BODY="$(cat "$DATA_FILE")"
  fi
elif [[ -n "$DATA" ]]; then
  BODY="$DATA"
fi

if [[ "$HAVE_BODY" -eq 1 ]]; then
  # Validate JSON to catch typos before hitting the API.
  if ! printf '%s' "$BODY" | jq empty >/dev/null 2>&1; then
    _emit_error 64 "bad_usage" message "request body is not valid JSON"
  fi
fi

# ─── curl assembly ───────────────────────────────────────────────────────

# If there are query params, encode them into the URL directly. This avoids
# the curl -G / --data-urlencode complication with non-GET methods (which
# would otherwise send the params as the body).
if [[ ${#QUERY_KEYS[@]} -gt 0 ]]; then
  qstr=""
  for i in "${!QUERY_KEYS[@]}"; do
    enc_key="$(jq -rn --arg v "${QUERY_KEYS[$i]}" '$v|@uri')"
    enc_val="$(jq -rn --arg v "${QUERY_VALS[$i]}" '$v|@uri')"
    qstr+="${qstr:+&}${enc_key}=${enc_val}"
  done
  sep="?"; [[ "$URL" == *"?"* ]] && sep="&"
  URL="${URL}${sep}${qstr}"
fi

CURL_ARGS=(-sS -L --max-time "${JIRASIK_API_TIMEOUT:-30}" -w $'\n%{http_code}' -X "$METHOD")
CURL_ARGS+=(-b "tenant.session.token=${TOKEN:-}")

if [[ "$HAVE_BODY" -eq 1 ]]; then
  CURL_ARGS+=(-H "Content-Type: application/json" --data-binary "$BODY")
fi

CURL_ARGS+=("$URL")

# Allow tests to inspect the exact curl invocation instead of running it.
if [[ -n "${JIRASIK_DEBUG_PRINT_CURL:-}" ]]; then
  printf 'curl'
  for a in "${CURL_ARGS[@]}"; do printf ' %q' "$a"; done
  printf '\n'
  exit 0
fi

# ─── Execute ─────────────────────────────────────────────────────────────

set +e
RAW_RESP="$(curl "${CURL_ARGS[@]}" 2>/dev/null)"
CURL_STATUS=$?
set -e

if [[ $CURL_STATUS -ne 0 ]]; then
  _emit_error 5 "http_server" \
    message "curl failed with exit code $CURL_STATUS" \
    status "000"
fi

HTTP_CODE="${RAW_RESP##*$'\n'}"
RESP_BODY="${RAW_RESP%$'\n'*}"

# ─── Status classification ───────────────────────────────────────────────

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  # Auth sanity check: some auth-failure pages return 200 with HTML.
  # If we asked the API (a REST endpoint) and got non-JSON, treat as auth_failed.
  if [[ -n "$RESP_BODY" ]] && ! printf '%s' "$RESP_BODY" | jq -e . >/dev/null 2>&1; then
    rm -f "${TOKEN_FILE:-/dev/null}" 2>/dev/null || true
    _emit_error 2 "auth_failed" \
      message "received non-JSON 2xx response; session likely invalid" \
      status "$HTTP_CODE"
  fi
  if [[ "$RAW" -eq 1 || -z "$RESP_BODY" ]]; then
    printf '%s' "$RESP_BODY"
    [[ -n "$RESP_BODY" ]] && printf '\n'
  else
    printf '%s\n' "$RESP_BODY" | jq .
  fi
  exit 0
fi

# Non-2xx: try to extract a useful message.
_msg=""
if printf '%s' "$RESP_BODY" | jq -e . >/dev/null 2>&1; then
  _msg="$(printf '%s' "$RESP_BODY" | jq -r '
    (.errorMessages // []) as $em
    | (.message // "") as $m
    | if ($em|length) > 0 then ($em | join("; "))
      elif $m != "" then $m
      else (tostring) end' 2>/dev/null || true)"
fi
[[ -z "$_msg" ]] && _msg="$RESP_BODY"

case "$HTTP_CODE" in
  401|403)
    rm -f "${TOKEN_FILE:-/dev/null}" 2>/dev/null || true
    _emit_error 2 "auth_failed" \
      message "${_msg:-session invalid or expired}" \
      status "$HTTP_CODE"
    ;;
  404)
    _emit_error 3 "not_found" \
      message "${_msg:-resource not found}" \
      path "$API_PATH" \
      status "$HTTP_CODE"
    ;;
  4*)
    _emit_error 4 "http_client" \
      message "$_msg" \
      status "$HTTP_CODE"
    ;;
  5*)
    _emit_error 5 "http_server" \
      message "$_msg" \
      status "$HTTP_CODE"
    ;;
  *)
    _emit_error 5 "http_server" \
      message "unexpected HTTP status: ${_msg:-unknown}" \
      status "$HTTP_CODE"
    ;;
esac
