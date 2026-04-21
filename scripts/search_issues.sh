#!/usr/bin/env bash
# Search Jira issues by JQL via the /rest/api/3/search/jql endpoint.
#
# The legacy /rest/api/3/search endpoint has been removed by Atlassian (see
# https://developer.atlassian.com/changelog/#CHANGE-2046). Always use this
# helper instead of hand-rolling a curl against the old path.
#
# Usage:
#   search_issues.sh <JQL>                        # default fields + 20 results
#   search_issues.sh <JQL> <FIELDS>               # custom fields (comma-sep)
#   search_issues.sh <JQL> <FIELDS> <MAX>         # custom maxResults
#   search_issues.sh --json <JQL> [FIELDS] [MAX]  # raw JSON output
#
# Examples:
#   search_issues.sh 'project=ERS AND issuetype=Epic AND summary~"Tech Debt"'
#   search_issues.sh 'assignee=currentUser() AND resolution=Unresolved' summary,status 50
#   search_issues.sh --json 'project=ERS' summary,status,assignee
#
# Default text output (one line per issue):
#   <KEY>\t<STATUS>\t<SUMMARY>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

JSON_OUTPUT=0
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=1
  shift
fi

JQL="${1:-}"
FIELDS="${2:-summary,status}"
MAX="${3:-20}"

if [[ -z "$JQL" ]]; then
  echo "Usage: search_issues.sh [--json] <JQL> [FIELDS] [MAX]" >&2
  exit 1
fi

RESPONSE=$("$JIRA_API" GET /search/jql --raw \
  --query "jql=$JQL" \
  --query "fields=$FIELDS" \
  --query "maxResults=$MAX")

# Surface API-level errors (e.g. invalid JQL) clearly. jira-api.sh already
# exits non-zero for HTTP errors, but a 200-with-errorMessages response can
# still happen for things like malformed JQL in some Jira versions.
if echo "$RESPONSE" | jq -e '.errorMessages // empty | length > 0' >/dev/null 2>&1; then
  echo "Jira API error:" >&2
  echo "$RESPONSE" | jq -r '.errorMessages[]' >&2
  exit 1
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  echo "$RESPONSE"
  exit 0
fi

echo "$RESPONSE" | jq -r '.issues[]? | "\(.key)\t\(.fields.status.name // "-")\t\(.fields.summary // "-")"'
