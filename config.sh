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
SKATE_KEY_JIRA_STATUSES="jira statuses"

JIRA_URL=$(skate get "$SKATE_KEY_JIRA_URL"@"$SKATE_DB" 2>&1)
JIRA_USER=$(skate get "$SKATE_KEY_JIRA_USER"@"$SKATE_DB" 2>&1)
JIRA_TOKEN=$(skate get "$SKATE_KEY_JIRA_TOKEN"@"$SKATE_DB" 2>&1)
JIRA_USERS=$(skate get "$SKATE_KEY_JIRA_USERS"@"$SKATE_DB" 2>&1)
JIRA_PROJECT_KEY=$(skate get "$SKATE_KEY_JIRA_PROJECT_KEY"@"$SKATE_DB" 2>&1)
JIRA_STATUSES=$(skate get "$SKATE_KEY_JIRA_STATUSES"@"$SKATE_DB" 2>&1)

function jira-cli-command {
    echo "Executing command: jira $@"
    JIRA_API_TOKEN=$JIRA_TOKEN jira $@
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
