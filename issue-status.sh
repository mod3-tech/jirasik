#!/usr/bin/env bash
. ./config

# Function to move an issue repeatedly until last status in the workflow is reached
move_issue_to_done() {
    local issue=$1
    local current_status=$2
    local next_status=""
    local found=false

    echo "Available statuses in workflow:"
    printf "  - %s\n" "${JIRA_STATUSES[@]}"
    echo "Current status: $current_status"

    while true; do
        # Look at JIRA_STATUSES to find the next status in the workflow
        next_status=""
        found=false

        for status in "${JIRA_STATUSES[@]}"; do
            if $found; then
                next_status=$status
                break
            fi
            if [ "$(echo "$status" | tr '[:upper:]' '[:lower:]')" = "$(echo "$current_status" | tr '[:upper:]' '[:lower:]')" ]; then
                found=true
            fi
        done

        # If no next status is found, abort the operation
        if [ -z "$next_status" ]; then
            echo "Status not found. Aborting."
            echo "Troubleshooting:"
            echo "  - Check that '$current_status' is in the JIRA_STATUSES array"
            echo "  - Check for exact case matching and whitespace"
            echo "  - Verify JIRA_STATUSES is defined as an array in config.sh"
            exit 1
        fi

        echo "Move issue $issue from $current_status to $next_status"

        # Create a temporary file for output
        temp_file=$(mktemp)

        # Run the interactive command and tee its output to both the terminal and the temp file
        jira-cli-command issue move $issue "$next_status" 2>&1 | tee "$temp_file"
        exit_code=${PIPESTATUS[0]}

        # Check if exit code is non-zero or output contains errors
        if [[ $exit_code -ne 0 ]] || grep -q "abort" "$temp_file" || grep -q "404" "$temp_file" || grep -q "error" "$temp_file"; then
            rm "$temp_file"
            exit 0
        fi

        # Check if the last status in the workflow has been reached
        if [[ $JIRA_STATUS_COUNT -gt 0 && "$(echo "$next_status" | tr '[:upper:]' '[:lower:]')" == "$(echo "${JIRA_STATUSES[$JIRA_STATUS_COUNT - 1]}" | tr '[:upper:]' '[:lower:]')" ]]; then
            echo "Issue $issue has reached the final status: $next_status"
            rm "$temp_file"
            exit 0
        fi

        # Update current_status to next_status for the next iteration
        current_status=$next_status

        # Clean up temp file for next iteration
        rm "$temp_file"
    done
}

# Function to move an issue one status at a time in a loop until cancelled
move_issue_one_at_a_time() {
    local issue=$1

    while true; do
        echo "Move issue $issue"

        # Create a temporary file for output
        temp_file=$(mktemp)

        # Run the interactive command and tee its output to both the terminal and the temp file
        jira-cli-command issue move $issue 2>&1 | tee "$temp_file"
        exit_code=${PIPESTATUS[0]}

        # Check if exit code is non-zero or output contains errors
        if [[ $exit_code -ne 0 ]] || grep -q "abort" "$temp_file" || grep -q "404" "$temp_file" || grep -q "error" "$temp_file"; then
            rm "$temp_file"
            exit 0
        fi

        # Clean up temp file for next iteration
        rm "$temp_file"
    done
}

JIRA_ISSUE=$(gum input --placeholder "Enter JIRA issue number ($JIRA_PROJECT_KEY-123)")

if [[ -z "$JIRA_ISSUE" ]]; then
    echo "No issue number provided."
    exit 1
fi

JIRA_ISSUE=$(echo $JIRA_PROJECT_KEY-$JIRA_ISSUE)

# Output the current issue's status
issue_status=$(jira-cli-command issue view $JIRA_ISSUE --raw | jq -r '.fields.status.name' 2>/dev/null)

echo "Current status of issue $JIRA_ISSUE: $issue_status"

while true; do
    choice=$(gum choose "Move to Done" "Move one status at a time" "Cancel")

    case $choice in
    "Move to Done")
        move_issue_to_done "$JIRA_ISSUE" "$issue_status"
        echo "Issue moved to Done."
        break
        ;;
    "Move one status at a time")
        move_issue_one_at_a_time "$JIRA_ISSUE"
        break
        ;;
    "Cancel")
        echo "Cancelled."
        exit 0
        ;;
    *)
        exit 0
        ;;
    esac
done
