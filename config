#!/usr/bin/env bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SKATE_DB="jirasik.db"
SKATE_KEY_JIRA_URL="jira url"
SKATE_KEY_JIRA_USER="jira user"
SKATE_KEY_JIRA_TOKEN="jira token"
SKATE_KEY_JIRA_USERS="jira users"
SKATE_KEY_JIRA_PROJECT_KEY="jira project key"
SKATE_KEY_JIRA_STATUS_COUNT="jira.status.count"
SKATE_KEY_JIRA_STATUS_PREFIX="jira.status."

JIRA_URL=$(skate get "$SKATE_KEY_JIRA_URL"@"$SKATE_DB" 2>&1)
JIRA_USER=$(skate get "$SKATE_KEY_JIRA_USER"@"$SKATE_DB" 2>&1)
JIRA_TOKEN=$(skate get "$SKATE_KEY_JIRA_TOKEN"@"$SKATE_DB" 2>&1)
JIRA_USERS=$(skate get "$SKATE_KEY_JIRA_USERS"@"$SKATE_DB" 2>&1)
JIRA_PROJECT_KEY=$(skate get "$SKATE_KEY_JIRA_PROJECT_KEY"@"$SKATE_DB" 2>&1)
JIRA_STATUSES=()
JIRA_STATUS_COUNT=$(skate get "$SKATE_KEY_JIRA_STATUS_COUNT"@"$SKATE_DB" 2>/dev/null || echo "0")
for ((i = 0; i < JIRA_STATUS_COUNT; i++)); do
    status=$(skate get "$SKATE_KEY_JIRA_STATUS_PREFIX$i"@"$SKATE_DB" 2>/dev/null)
    if [ -n "$status" ]; then
        JIRA_STATUSES+=("$status")
    fi
done

function jira-cli-command {
    JIRA_API_TOKEN=$JIRA_TOKEN jira "$@"
}

function jira-curl-command {
    local endpoint="$JIRA_URL$@"
    local response
    response=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" "$endpoint")

    if [ $? -ne 0 ]; then
        echo "Error fetching data" >&2
        return 1
    fi

    echo "$response"
}
