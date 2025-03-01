#!/usr/bin/env bash
. ./config.sh

echo -e "\n"

# TODO figure out how to determine customfield id
CUSTOMFIELD_ID="customfield_10026"

# Function to format the totals row with colors
function format_totals_row {
    local width=$1
    local assignee=$2
    local todo=$3
    local inprogress=$4
    local done=$5
    local ignored=$6

    local assignee_col=$(printf "%-${width}s" "$assignee")
    # Only colorize if the value is not zero
    if [ "$todo" -ne 0 ]; then
        todo_str=$(gum style --foreground 244 "$(printf "%8s" "$todo")")
    else
        todo_str=$(printf "%8s" "$todo")
    fi

    if [ "$inprogress" -ne 0 ]; then
        inprogress_str=$(gum style --foreground 33 "$(printf "%12s" "$inprogress")")
    else
        inprogress_str=$(printf "%12s" "$inprogress")
    fi

    if [ "$done" -ne 0 ]; then
        done_str=$(gum style --foreground 76 "$(printf "%8s" "$done")")
    else
        done_str=$(printf "%8s" "$done")
    fi

    if [ "$ignored" -ne 0 ]; then
        ignored_str=$(gum style --foreground 201 "$(printf "%8s" "$ignored")")
    else
        ignored_str=$(printf "%8s" "$ignored")
    fi

    echo "${assignee_col} ${todo_str} ${inprogress_str} ${done_str} ${ignored_str}"
}

# Get board id of scrum board
BOARD_ID=$(jira-curl-command "/rest/agile/1.0/board/" | jq -r --arg key "$JIRA_PROJECT_KEY" --arg type "scrum" '.values[] | select(.location.projectKey == $key and .type == $type).id')

# Get active sprint information
SPRINT_DATA=$(jira-curl-command "/rest/agile/1.0/board/$BOARD_ID/sprint" | jq -r '.values[] | select(.state == "active") | {id: .id, name: .name}')
SPRINT_ID=$(echo "$SPRINT_DATA" | jq -r '.id')
SPRINT_NAME=$(echo "$SPRINT_DATA" | jq -r '.name')
echo "Sprint: $(gum style --bold "$SPRINT_NAME")"

# Get issues from current sprint
SPRINT_ISSUES=$(jira-curl-command "/rest/agile/1.0/board/$BOARD_ID/sprint/$SPRINT_ID/issue?fields=assignee,status,resolution,$CUSTOMFIELD_ID&maxResults=100")

# Total points separately by the status and resolution of the issue
TOTAL_TODO=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select(.fields.status.name == "Not Started" and .fields.resolution == null) | .fields[$field] // 0' | awk '{sum+=$1} END {print sum}')
TOTAL_IN_PROGRESS=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select(.fields.status.name != "Not Started" and .fields.resolution == null) | .fields[$field] // 0' | awk '{sum+=$1} END {print sum}')
TOTAL_DONE=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select(.fields.status.name == "Done" and (.fields.resolution.name != "Won'\''t Do")) | .fields[$field] // 0' | awk '{sum+=$1} END {print sum}')
TOTAL_IGNORED=$(echo "$SPRINT_ISSUES" | jq -r --arg field "$CUSTOMFIELD_ID" '.issues[] | select (.fields.resolution.name == "Won'\''t Do") | .fields[$field] // 0' | awk '{sum+=$1} END {print sum}')

# printf "%15s %8s\n" "To Do:" "$(gum style --foreground 244 "$TOTAL_TODO")"
# printf "%15s %8s\n" "In Progress:" "$(gum style --foreground 33 "$TOTAL_IN_PROGRESS")"
# printf "%15s %8s\n" "Done:" "$(gum style --foreground 76 "$TOTAL_DONE")"
# printf "%15s %8s\n" "Ignored:" "$(gum style --foreground 201 "$TOTAL_IGNORED")"

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
