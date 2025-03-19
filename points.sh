#!/usr/bin/env bash
. ./config

echo -e "\n"

# Get customfield id associated with Story Points
CUSTOMFIELD_ID=$(grep -A 2 "Story Points" $JIRACLI_CONFIG_FILE | grep "key:" | awk '{print $2}')

# Function to format the totals row with colors
function format_totals_row {
    local width=$1
    local assignee=$2
    local todo=${3:-0}
    local inprogress=${4:-0}
    local done=${5:-0}
    local ignored=${6:-0}

    local assignee_col=$(printf "%-${width}s" "$assignee")
    # Only colorize if the value is not zero
    if [ "${todo:-0}" -ne 0 ]; then
        todo_str=$(gum style --foreground 244 "$(printf "%8s" "$todo")")
    else
        todo_str=$(printf "%8s" "$todo")
    fi

    if [ "${inprogress:-0}" -ne 0 ]; then
        inprogress_str=$(gum style --foreground 33 "$(printf "%12s" "$inprogress")")
    else
        inprogress_str=$(printf "%12s" "$inprogress")
    fi

    if [ "${done:-0}" -ne 0 ]; then
        done_str=$(gum style --foreground 76 "$(printf "%8s" "$done")")
    else
        done_str=$(printf "%8s" "$done")
    fi

    if [ "${ignored:-0}" -ne 0 ]; then
        ignored_str=$(gum style --foreground 201 "$(printf "%8s" "$ignored")")
    else
        ignored_str=$(printf "%8s" "$ignored")
    fi

    echo "${assignee_col} ${todo_str} ${inprogress_str} ${done_str} ${ignored_str}"
}

# Get active sprint information
SPRINT_DATA=$(jira-curl-command "/rest/agile/1.0/board/$JIRA_BOARD_ID/sprint" | jq -r '.values[] | select(.state == "active") | {id: .id, name: .name}')
SPRINT_ID=$(echo "$SPRINT_DATA" | jq -r '.id')
SPRINT_NAME=$(echo "$SPRINT_DATA" | jq -r '.name')
echo "Sprint: $(gum style --bold "$SPRINT_NAME")"

# Get issues from current sprint
SPRINT_ISSUES=$(jira-curl-command "/rest/agile/1.0/board/$JIRA_BOARD_ID/sprint/$SPRINT_ID/issue?fields=assignee,status,resolution,$CUSTOMFIELD_ID&maxResults=100")

# Total points separately by the status and resolution of the issue
TOTAL_TODO=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select(.fields.status.name == "Not Started" and .fields.resolution == null) | .fields[$field] // 0' | awk '{sum+=$1} END {print sum+0}')
TOTAL_IN_PROGRESS=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select(.fields.status.name != "Not Started" and .fields.resolution == null) | .fields[$field] // 0' | awk '{sum+=$1} END {print sum+0}')
TOTAL_DONE=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select(.fields.status.name == "Done" and (.fields.resolution.name != "Won'\''t Do")) | .fields[$field] // 0' | awk '{sum+=$1} END {print sum+0}')
TOTAL_IGNORED=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select (.fields.resolution.name == "Won'\''t Do") | .fields[$field] // 0' | awk '{sum+=$1} END {print sum+0}')

# Add more spacing between sections
echo -e "\n"

# Get point totals by assignee
echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '
    .issues[] |
    {
        assignee: (.fields.assignee.displayName // "Unassigned"),
        points: (.fields[$field] // 0),
        status: (
            if .fields.status.name == "Done" and .fields.resolution.name != "Won'\''t Do" then "Done"
            elif .fields.resolution.name == "Won'\''t Do" then "Ignored"
            elif .fields.status.name == "Not Started" and .fields.resolution == null then "To Do"
            elif .fields.status.name != "Done" and .fields.resolution == null then "In Progress"
            else "Other"
            end
        )
    }' |
    jq -s 'group_by(.assignee) | map({
        assignee: .[0].assignee,
        todo: (map(select(.status == "To Do") | .points) | add // 0 | round),
        inProgress: (map(select(.status == "In Progress") | .points) | add // 0 | round),
        done: (map(select(.status == "Done") | .points) | add // 0 | round),
        ignored: (map(select(.status == "Ignored") | .points) | add // 0 | round)
    })' |
    jq -r 'sort_by(.assignee == "Unassigned", .assignee) | .[] | [.assignee, .todo, .inProgress, .done, .ignored] | map(tostring) | join(",")' >temp_data.csv

# Add totals row to the CSV
echo "Total,$TOTAL_TODO,$TOTAL_IN_PROGRESS,$TOTAL_DONE,$TOTAL_IGNORED" >>temp_data.csv

# Get the maximum width needed for the assignee column
max_width=$(awk -F, '{print length($1)}' temp_data.csv | sort -nr | head -1)
# Add some padding
column_width=$((max_width + 3))

# Print header with dynamic width
printf "%-${column_width}s %8s %12s %8s %8s\n" "Assignee" "To Do" "In Progress" "Done" "Ignored" | gum style --bold
printf "%s\n" "$(printf '=%.0s' $(seq 1 $((column_width + 40))))"

# Print data rows (except the last one which is totals)
line_count=$(wc -l <temp_data.csv)
while IFS=, read -r assignee todo inprogress done ignored; do
    format_totals_row "$column_width" "$assignee" "$todo" "$inprogress" "$done" "$ignored"
done < <(head -n $(($(wc -l <temp_data.csv) - 1)) temp_data.csv)

# Print separator before totals
printf "%s\n" "$(printf -- '-%.0s' $(seq 1 $((column_width + 40))))"

# Print totals row with emphasis
format_totals_row "$column_width" "Totals" "$TOTAL_TODO" "$TOTAL_IN_PROGRESS" "$TOTAL_DONE" "$TOTAL_IGNORED"

echo -e "\n"

# Clean up
rm temp_data.csv
