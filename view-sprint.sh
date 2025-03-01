#!/usr/bin/env bash
. ./config.sh

## Get configured Jira users
SELECTED_USER=$(gum filter "Current user ($JIRA_USER)" "All users" $JIRA_USERS)

if [[ -z "$SELECTED_USER" ]]; then
    exit 1
fi

if [[ "$SELECTED_USER" == "All users" ]]; then
    jira-cli-command sprint list --current
elif [[ "$SELECTED_USER" == "Current user"* ]]; then
    jira-cli-command sprint list --current -a$JIRA_USER
else
    jira-cli-command sprint list --current -a$SELECTED_USER
fi
