#!/usr/bin/env bash
. ./config

# Get active sprint information
SPRINT_DATA=$(jira-curl-command "/rest/agile/1.0/board/$JIRA_BOARD_ID/sprint" | jq -r '.values[] | select(.state == "active") | {id: .id, name: .name}')
SPRINT_ID=$(echo "$SPRINT_DATA" | jq -r '.id')
SPRINT_NAME=$(echo "$SPRINT_DATA" | jq -r '.name')

# Get issues from current sprint
SPRINT_ISSUES=$(jira-curl-command "/rest/agile/1.0/board/$JIRA_BOARD_ID/sprint/$SPRINT_ID/issue?fields=assignee$CUSTOMFIELD_ID&maxResults=100")

JIRA_USERS_ARRAY=()
while read -r user; do
    if [[ -n "$user" && "$user" != "$JIRA_USER" ]]; then
        JIRA_USERS_ARRAY+=("$user")
    fi
done < <(echo "$SPRINT_ISSUES" | jq -r '.issues[] | select(.fields.assignee != null) | .fields.assignee.emailAddress' | sort -u)

# Add "All users" and "Unassigned" options
SELECTED_USER=$(gum filter "Current user <$JIRA_USER>" "Unassigned" "All users" "${JIRA_USERS_ARRAY[@]}")

if [[ -z "$SELECTED_USER" ]]; then
    exit 1
fi

if [[ "$SELECTED_USER" == "All users" ]]; then
    jira-cli-command sprint list --current
elif [[ "$SELECTED_USER" == "Current user"* ]]; then
    jira-cli-command sprint list --current -a$JIRA_USER
elif [[ "$SELECTED_USER" == "Unassigned" ]]; then
    jira-cli-command issue list -q 'sprint in openSprints() AND assignee IS EMPTY'
else
    jira-cli-command sprint list --current -a$SELECTED_USER
fi
