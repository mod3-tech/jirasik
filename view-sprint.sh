#!/usr/bin/env bash
. ./config

## Get configured Jira users
SELECTED_USER=$(gum filter "Current user ($JIRA_USER)" "All users" "Unassigned" $JIRA_USERS)

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
