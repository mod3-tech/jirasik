#!/usr/bin/env bash
. ./config.sh

function add-users {
    if [[ "$JIRA_USERS" == *"Key not found"* ]] || [[ -z "$JIRA_USERS" ]]; then
        echo "No JIRA users found"
        JIRA_USERS=""
    fi

    echo "Add users one at a time below..."

    while true; do
        USER_EMAIL=$(gum input --placeholder "Enter user email (leave empty to finish)")
        if [[ -z "$USER_EMAIL" ]]; then
            break
        fi
        # Add the email to the JSON array
        if [[ "$JIRA_USERS" == "" ]]; then
            JIRA_USERS="$USER_EMAIL"
        else
            JIRA_USERS="${JIRA_USERS} $USER_EMAIL"
        fi
        echo "Added $USER_EMAIL"
    done
    echo "JIRA_USERS: $JIRA_USERS"

    skate set "$SKATE_KEY_JIRA_USERS"@"$SKATE_DB" "$JIRA_USERS"
}

add-users
