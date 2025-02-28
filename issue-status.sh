#!/usr/bin/env bash
. ./config.sh

JIRA_ISSUE=$(gum input --placeholder "Enter JIRA issue number ($JIRA_ISSUE_KEY-123)")

if [[ ! -z "$JIRA_ISSUE" ]]; then
    # Loop indefinitely until user cancels
    while true; do
        echo "Move issue ($JIRA_ISSUE_KEY-$JIRA_ISSUE)"

        # Create a temporary file for output
        temp_file=$(mktemp)

        # Run the interactive command and tee its output to both the terminal and the temp file
        jira-cli-command issue move $JIRA_ISSUE_KEY-$JIRA_ISSUE 2>&1 | tee "$temp_file"
        exit_code=${PIPESTATUS[0]}

        # Check if exit code is non-zero or output contains errors
        if [[ $exit_code -ne 0 ]] || grep -q "abort" "$temp_file" || grep -q "404" "$temp_file" || grep -q "error" "$temp_file"; then
            rm "$temp_file"
            exit 0
        fi

        # Clean up temp file for next iteration
        rm "$temp_file"
    done
fi
