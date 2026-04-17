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

RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  -G \
  --data-urlencode "jql=$JQL" \
  --data-urlencode "fields=$FIELDS" \
  --data-urlencode "maxResults=$MAX" \
  "$JIRA/rest/api/3/search/jql")

check_auth "$RESPONSE" "."

# Surface API-level errors (e.g. removed endpoint, invalid JQL) clearly.
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
