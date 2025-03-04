#!/usr/bin/env bash
. ./config.sh

if [[ "$JIRA_STATUSES" == *"Key not found"* ]] || [ -z "$JIRA_STATUSES" ]; then
    if [[ "$JIRA_STATUSES" == *"Key not found"* ]]; then
        JIRA_STATUSES=()
    fi

    while true; do
        status=$(gum input --placeholder "Enter status one at a time in order (leave empty to finish):")
        if [ -z "$status" ]; then
            break
        fi
        JIRA_STATUSES+=("\"$status\"")
        echo "Status added: $status"
    done

    echo "Statuses saved: ${JIRA_STATUSES[@]}"
    skate set "$SKATE_KEY_JIRA_STATUSES"@"$SKATE_DB" "${JIRA_STATUSES[@]}"
fi

# "NOT STARTED"  "READY FOR DEVELOPMENT"  "IN PROGRESS"  "READY FOR REVIEW"  "IN REVIEW"  "READY FOR QA"  "IN QA"  "To Demo"  "DONE"