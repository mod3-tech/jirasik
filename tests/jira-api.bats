#!/usr/bin/env bats

# Tests for scripts/jira-api.sh
#
# Strategy:
# - JIRASIK_SKIP_AUTH_BOOTSTRAP=1 bypasses sourcing auth.sh so tests don't
#   need a real Jira config or session.
# - We export JIRA + TOKEN directly.
# - For URL/argument tests we use JIRASIK_DEBUG_PRINT_CURL=1 which prints the
#   curl invocation and exits 0 instead of making a network call.
# - For HTTP-response tests we install a fake `curl` on PATH that writes a
#   fixture to stdout.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/jira-api.sh"

setup() {
  export JIRA="https://example.atlassian.net"
  export TOKEN="test-token"
  export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
  SHIM_DIR="$(mktemp -d)"
  export SHIM_DIR
}

teardown() {
  [[ -n "${SHIM_DIR:-}" && -d "$SHIM_DIR" ]] && rm -rf "$SHIM_DIR"
  unset JIRASIK_DEBUG_PRINT_CURL MOCK_BODY MOCK_CODE
}

# Install a fake `curl` that emits $MOCK_BODY + newline + $MOCK_CODE.
install_curl_shim() {
  cat > "$SHIM_DIR/curl" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n%s' "${MOCK_BODY:-}" "${MOCK_CODE:-200}"
SHIM
  chmod +x "$SHIM_DIR/curl"
  export PATH="$SHIM_DIR:$PATH"
}

# ─── Usage / argument validation ────────────────────────────────────────

@test "exits with bad_usage when no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 64 ]
  [[ "$output" == *'"error":"bad_usage"'* ]]
}

@test "exits with bad_usage for unsupported METHOD" {
  run "$SCRIPT" FROBNICATE /foo
  [ "$status" -eq 64 ]
  [[ "$output" == *'unsupported METHOD'* ]]
}

@test "exits with bad_usage for unknown flag" {
  run "$SCRIPT" GET /foo --nonsense
  [ "$status" -eq 64 ]
  [[ "$output" == *'unknown argument'* ]]
}

@test "exits with bad_usage when --query missing '='" {
  run "$SCRIPT" GET /foo --query justakey
  [ "$status" -eq 64 ]
  [[ "$output" == *'KEY=VALUE'* ]]
}

@test "exits with bad_usage when --data contains invalid JSON" {
  run "$SCRIPT" POST /foo --data 'not json'
  [ "$status" -eq 64 ]
  [[ "$output" == *'not valid JSON'* ]]
}

@test "exits with bad_usage when --data-file path doesn't exist" {
  run "$SCRIPT" POST /foo --data-file /nope/missing.json
  [ "$status" -eq 64 ]
  [[ "$output" == *'data file not found'* ]]
}

@test "-h prints help and exits 0" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *'USAGE'* ]]
  [[ "$output" == *'jira-api.sh'* ]]
  # Should not include the shebang line.
  [[ "$output" != *'/usr/bin/env bash'* ]]
}

# ─── Removed-endpoint guard ─────────────────────────────────────────────

@test "guards against /rest/api/3/search" {
  run "$SCRIPT" GET /rest/api/3/search
  [ "$status" -eq 6 ]
  [[ "$output" == *'"error":"removed_endpoint"'* ]]
  [[ "$output" == *'CHANGE-2046'* ]]
}

@test "guards against bare /search" {
  run "$SCRIPT" GET /search
  [ "$status" -eq 6 ]
  [[ "$output" == *'"error":"removed_endpoint"'* ]]
}

@test "allows /search/jql (the replacement endpoint)" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /search/jql --query jql=project=PROG
  [ "$status" -eq 0 ]
  [[ "$output" == *'/rest/api/3/search/jql'* ]]
}

# ─── URL construction ───────────────────────────────────────────────────

@test "default base is /rest/api/3" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /issue/PROG-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'https://example.atlassian.net/rest/api/3/issue/PROG-1'* ]]
}

@test "--agile uses /rest/agile/1.0 base" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /board --agile
  [ "$status" -eq 0 ]
  [[ "$output" == *'https://example.atlassian.net/rest/agile/1.0/board'* ]]
}

@test "--wiki uses /wiki/rest/api base" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /content/123 --wiki
  [ "$status" -eq 0 ]
  [[ "$output" == *'https://example.atlassian.net/wiki/rest/api/content/123'* ]]
}

@test "absolute /rest path is used as-is" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /rest/api/3/myself
  [ "$status" -eq 0 ]
  [[ "$output" == *'https://example.atlassian.net/rest/api/3/myself'* ]]
}

@test "path without leading slash gets one added" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET issue/PROG-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'/rest/api/3/issue/PROG-1'* ]]
}

# ─── Query encoding ─────────────────────────────────────────────────────

@test "--query encodes special chars (spaces, =, quotes)" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /search/jql --query 'jql=project=PROG AND summary~"foo bar"'
  [ "$status" -eq 0 ]
  # %3D = '=', %20 = ' ', %22 = '"'
  [[ "$output" == *'jql=project%3DPROG%20AND%20summary~%22foo%20bar%22'* ]]
}

@test "multiple --query values produce &-joined string" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" GET /search/jql --query jql=project=PROG --query fields=summary,status
  [ "$status" -eq 0 ]
  [[ "$output" == *'jql=project%3DPROG'* ]]
  [[ "$output" == *'fields=summary%2Cstatus'* ]]
  [[ "$output" == *'&'* ]]
}

@test "--query works on POST (in URL, not body)" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" POST /issue --data '{"a":1}' --query notifyUsers=false
  [ "$status" -eq 0 ]
  [[ "$output" == *'?notifyUsers=false'* ]]
  [[ "$output" == *'--data-binary'* ]]
}

# ─── Body handling ──────────────────────────────────────────────────────

@test "--data inline JSON is sent as body" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" PUT /issue/PROG-1 --data '{"fields":{"customfield_10026":5}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'--data-binary'* ]]
  [[ "$output" == *'customfield_10026'* ]]
  [[ "$output" == *'Content-Type'* ]]
}

@test "--data-file reads body from file" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  tmp="$(mktemp)"
  echo '{"foo":"bar"}' > "$tmp"
  run "$SCRIPT" POST /issue/PROG-1/comment --data-file "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
  # Debug output uses printf %q, which backslash-escapes quotes.
  [[ "$output" == *'foo'* ]]
  [[ "$output" == *'bar'* ]]
  [[ "$output" == *'--data-binary'* ]]
}

@test "--data-file - reads body from stdin" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  result="$(echo '{"stdin":true}' | "$SCRIPT" POST /issue --data-file -)"
  [[ "$result" == *'stdin'* ]]
  [[ "$result" == *'true'* ]]
  [[ "$result" == *'--data-binary'* ]]
}

# ─── Method handling ────────────────────────────────────────────────────

@test "method is upper-cased" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" get /issue/PROG-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'-X GET'* ]]
}

@test "supports DELETE" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" DELETE /issue/PROG-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'-X DELETE'* ]]
}

@test "supports PATCH" {
  export JIRASIK_DEBUG_PRINT_CURL=1
  run "$SCRIPT" PATCH /issue/PROG-1 --data '{"a":1}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'-X PATCH'* ]]
}

# ─── HTTP status classification (with shimmed curl) ─────────────────────

@test "2xx JSON response is pretty-printed to stdout" {
  install_curl_shim
  export MOCK_CODE=200 MOCK_BODY='{"key":"PROG-1","summary":"hi"}'
  run "$SCRIPT" GET /issue/PROG-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'"key"'* ]]
  [[ "$output" == *'"summary"'* ]]
  # pretty-printed means newline between fields
  lines_count=$(printf '%s' "$output" | wc -l)
  [ "$lines_count" -ge 2 ]
}

@test "2xx with --raw preserves compact JSON" {
  install_curl_shim
  export MOCK_CODE=200 MOCK_BODY='{"a":1,"b":2}'
  run "$SCRIPT" GET /foo --raw
  [ "$status" -eq 0 ]
  [[ "$output" == '{"a":1,"b":2}' ]]
}

@test "2xx with empty body succeeds (e.g. 204 No Content)" {
  install_curl_shim
  export MOCK_CODE=204 MOCK_BODY=""
  run "$SCRIPT" DELETE /issue/PROG-1
  [ "$status" -eq 0 ]
}

@test "2xx with non-JSON body is flagged as auth_failed" {
  install_curl_shim
  export MOCK_CODE=200 MOCK_BODY='<html>Login required</html>'
  run "$SCRIPT" GET /issue/PROG-1
  [ "$status" -eq 2 ]
  [[ "$output" == *'"error":"auth_failed"'* ]]
}

@test "401 maps to auth_failed (exit 2)" {
  install_curl_shim
  export MOCK_CODE=401 MOCK_BODY='{"message":"unauthorized"}'
  run "$SCRIPT" GET /issue/PROG-1
  [ "$status" -eq 2 ]
  [[ "$output" == *'"error":"auth_failed"'* ]]
  [[ "$output" == *'"status":401'* ]]
}

@test "403 maps to auth_failed" {
  install_curl_shim
  export MOCK_CODE=403 MOCK_BODY='{"message":"forbidden"}'
  run "$SCRIPT" GET /issue/PROG-1
  [ "$status" -eq 2 ]
  [[ "$output" == *'"error":"auth_failed"'* ]]
}

@test "404 maps to not_found (exit 3)" {
  install_curl_shim
  export MOCK_CODE=404 MOCK_BODY='{"errorMessages":["Issue does not exist"]}'
  run "$SCRIPT" GET /issue/NOPE-1
  [ "$status" -eq 3 ]
  [[ "$output" == *'"error":"not_found"'* ]]
  [[ "$output" == *'Issue does not exist'* ]]
  [[ "$output" == *'"path":"/issue/NOPE-1"'* ]]
}

@test "400 maps to http_client (exit 4)" {
  install_curl_shim
  export MOCK_CODE=400 MOCK_BODY='{"errorMessages":["Bad JQL"]}'
  run "$SCRIPT" GET /search/jql --query jql=invalid
  [ "$status" -eq 4 ]
  [[ "$output" == *'"error":"http_client"'* ]]
  [[ "$output" == *'"status":400'* ]]
  [[ "$output" == *'Bad JQL'* ]]
}

@test "500 maps to http_server (exit 5)" {
  install_curl_shim
  export MOCK_CODE=500 MOCK_BODY='{"message":"boom"}'
  run "$SCRIPT" GET /issue/PROG-1
  [ "$status" -eq 5 ]
  [[ "$output" == *'"error":"http_server"'* ]]
  [[ "$output" == *'"status":500'* ]]
}

@test "error response status is numeric (not string) in JSON output" {
  install_curl_shim
  export MOCK_CODE=404 MOCK_BODY='{"errorMessages":["x"]}'
  run "$SCRIPT" GET /issue/NOPE
  [ "$status" -eq 3 ]
  # Numeric status means "status":404 — not "status":"404"
  [[ "$output" == *'"status":404'* ]]
  [[ "$output" != *'"status":"404"'* ]]
}
