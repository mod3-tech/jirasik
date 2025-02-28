#!/usr/bin/env bash
. ./config.sh

function list-users {
    if [[ "$JIRA_USERS" == *"Key not found"* ]] || [[ -z "$JIRA_USERS" ]]; then
        echo "No users to list"
        exit 0
    fi

    echo "Current list of users:"
    echo "$JIRA_USERS" | tr ' ' '\n'
}

function add-users {
    if [[ "$JIRA_USERS" == *"Key not found"* ]] || [[ -z "$JIRA_USERS" ]]; then
        JIRA_USERS=""
    fi

    list-users

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
            # Add the email and sort alphabetically
            JIRA_USERS="${JIRA_USERS} $USER_EMAIL"
            JIRA_USERS=$(echo "$JIRA_USERS" | tr ' ' '\n' | sort | tr '\n' ' ')
        fi
        echo "Added $USER_EMAIL"
    done

    skate set "$SKATE_KEY_JIRA_USERS"@"$SKATE_DB" "$JIRA_USERS"
}

function remove-users {
    if [[ "$JIRA_USERS" == *"Key not found"* ]] || [[ -z "$JIRA_USERS" ]]; then
        echo "No users to remove"
        JIRA_USERS=""
        exit 0
    fi

    echo "Remove users one at a time below..."

    while true; do
        # Use gum to list existing users to remove
        USER_EMAIL=$(gum choose --header "Select user to remove" $JIRA_USERS "Cancel")
        if [[ -z "$USER_EMAIL" ]] || [[ "$USER_EMAIL" == "Cancel" ]]; then
            echo "Have a nice day!"
            exit 0
        fi

        # Remove the email from the JSON array
        JIRA_USERS=$(echo "$JIRA_USERS" | tr ' ' '\n' | grep -v "$USER_EMAIL" | tr '\n' ' ')
        echo "Removed $USER_EMAIL"
        skate set "$SKATE_KEY_JIRA_USERS"@"$SKATE_DB" "$JIRA_USERS"
    done
}

while true; do
    # Ask user to add, remove, or cancel
    ACTION=$(gum choose --header "What would you like to do?" "Add users" "Remove users" "List users" "Cancel")

    # Check if user pressed Escape (gum returns empty when Escape is pressed)
    if [[ -z "$ACTION" ]]; then
        echo "Cancelled. Have a nice day!"
        exit 0
    fi

    case "$ACTION" in
        "Add users")
            add-users
            ;;
        "Remove users")
            remove-users
            ;;
        "List users")
            list-users
            ;;
        "Cancel")
            echo "Have a nice day!"
            exit 0
            ;;
    esac
done
