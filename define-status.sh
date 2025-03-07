#!/usr/bin/env bash
. ./config

if [ ${#JIRA_STATUSES[@]} -eq 0 ]; then
    JIRA_STATUSES=()
fi

while true; do
    echo "Current statuses: ${JIRA_STATUSES[@]}"
    if gum confirm "Do you want to overwrite existing statuses?"; then
        JIRA_STATUSES=()

        # Remove all existing status entries from skate
        for ((i = 0; i < JIRA_STATUS_COUNT; i++)); do
            skate delete "$SKATE_KEY_JIRA_STATUS_PREFIX$i"@"$SKATE_DB" 2>/dev/null
        done

        # Reset the count to 0
        skate set "$SKATE_KEY_JIRA_STATUS_COUNT"@"$SKATE_DB" "0"

        echo "Existing statuses cleared."
        break
    else
        echo "Cancelled."
        exit 0
    fi
done

while true; do
    status=$(gum input --placeholder "Enter status one at a time in order (leave empty to finish):")
    if [ -z "$status" ]; then
        break
    fi
    JIRA_STATUSES+=("$status")
    echo "Status added: $status"
done

# Save the count first
skate set "$SKATE_KEY_JIRA_STATUS_COUNT"@"$SKATE_DB" "${#JIRA_STATUSES[@]}"

# Save each status individually to skate
for i in "${!JIRA_STATUSES[@]}"; do
    skate set "$SKATE_KEY_JIRA_STATUS_PREFIX$i"@"$SKATE_DB" "${JIRA_STATUSES[$i]}"
done

echo "Statuses saved: ${JIRA_STATUSES[@]}"

# not started
# ready for development
# in progress
# ready for review
# in review
# ready for qa
# in qa
# to demo
# done
