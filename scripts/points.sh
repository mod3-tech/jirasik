#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

# --- 1. Fetch all sprint issues ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/search/jql?jql=sprint%20in%20(openSprints())%20ORDER%20BY%20assignee%20ASC&fields=summary,status,assignee,customfield_10026,customfield_10021,resolution&maxResults=100")

check_auth "$RESPONSE" ".issues"

# --- 3. Format output ---

BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
GREEN=$'\033[32m'
MAGENTA=$'\033[35m'

# Sprint name
SPRINT=$(echo "$RESPONSE" | jq -r '
  [.issues[].fields.customfield_10021[]? | select(.state == "active") | .name] | unique | first // "Unknown Sprint"
')
echo ""
echo "${BOLD}Sprint Points${RST}"
echo "${DIM}${SPRINT}${RST}"
echo ""

# --- 4. Compute per-assignee breakdown ---
# Categorize: To Do = not started + no resolution
#             In Progress = not done + no resolution
#             Done = done + resolution != "Won't Do"
#             Ignored = resolution == "Won't Do"
ROWS=$(echo "$RESPONSE" | jq -r '
  [ .issues[] |
    {
      assignee: (.fields.assignee.displayName // "Unassigned"),
      points: (.fields.customfield_10026 // 0),
      category: (
        if .fields.resolution.name == "Won'\''t Do" then "ignored"
        elif .fields.status.statusCategory.name == "Done" then "done"
        elif .fields.status.statusCategory.name == "New" then "todo"
        else "inprogress"
        end
      )
    }
  ] | group_by(.assignee) | map({
    assignee: .[0].assignee,
    todo: ([ .[] | select(.category == "todo") | .points ] | add // 0 | floor),
    inprogress: ([ .[] | select(.category == "inprogress") | .points ] | add // 0 | floor),
    done: ([ .[] | select(.category == "done") | .points ] | add // 0 | floor),
    ignored: ([ .[] | select(.category == "ignored") | .points ] | add // 0 | floor)
  }) | sort_by(.assignee == "Unassigned", .assignee)
  | .[] | [.assignee, (.todo|tostring), (.inprogress|tostring), (.done|tostring), (.ignored|tostring)] | join("\t")
')

# --- 5. Compute column widths ---
W_A=8; W_T=5; W_I=11; W_D=4; W_IG=7
while IFS=$'\t' read -r assignee todo ip done ignored; do
  [[ -z "$assignee" ]] && continue
  (( ${#assignee} > W_A )) && W_A=${#assignee}
  (( ${#todo} > W_T )) && W_T=${#todo}
  (( ${#ip} > W_I )) && W_I=${#ip}
  (( ${#done} > W_D )) && W_D=${#done}
  (( ${#ignored} > W_IG )) && W_IG=${#ignored}
done <<< "$ROWS"

TOTAL_W=$(( 2 + W_A + 2 + W_T + 2 + W_I + 2 + W_D + 2 + W_IG ))

# Header
printf "  ${BOLD}%-${W_A}s  %${W_T}s  %${W_I}s  %${W_D}s  %${W_IG}s${RST}\n" \
  "Assignee" "To Do" "In Progress" "Done" "Ignored"
printf "  ${DIM}"
printf '%.0s─' $(seq 1 "$TOTAL_W")
printf "${RST}\n"

# --- 6. Print rows ---
while IFS=$'\t' read -r assignee todo ip done ignored; do
  [[ -z "$assignee" ]] && continue

  printf "  %-${W_A}s" "$assignee"
  if [[ "$todo" -ne 0 ]]; then
    printf "  ${DIM}%${W_T}s${RST}" "$todo"
  else
    printf "  %${W_T}s" "$todo"
  fi
  if [[ "$ip" -ne 0 ]]; then
    printf "  ${BLUE}%${W_I}s${RST}" "$ip"
  else
    printf "  %${W_I}s" "$ip"
  fi
  if [[ "$done" -ne 0 ]]; then
    printf "  ${GREEN}%${W_D}s${RST}" "$done"
  else
    printf "  %${W_D}s" "$done"
  fi
  if [[ "$ignored" -ne 0 ]]; then
    printf "  ${MAGENTA}%${W_IG}s${RST}" "$ignored"
  else
    printf "  %${W_IG}s" "$ignored"
  fi
  printf "\n"
done <<< "$ROWS"

# --- 7. Totals ---
TOTAL_TODO=$(echo "$RESPONSE" | jq '[.issues[] | select(.fields.status.statusCategory.name == "New" and .fields.resolution == null) | .fields.customfield_10026 // 0] | add // 0 | floor')
TOTAL_IP=$(echo "$RESPONSE" | jq '[.issues[] | select(.fields.status.statusCategory.name != "New" and .fields.status.statusCategory.name != "Done" and .fields.resolution == null) | .fields.customfield_10026 // 0] | add // 0 | floor')
TOTAL_DONE=$(echo "$RESPONSE" | jq '[.issues[] | select(.fields.status.statusCategory.name == "Done" and (.fields.resolution.name != "Won'\''t Do")) | .fields.customfield_10026 // 0] | add // 0 | floor')
TOTAL_IGNORED=$(echo "$RESPONSE" | jq '[.issues[] | select(.fields.resolution.name == "Won'\''t Do") | .fields.customfield_10026 // 0] | add // 0 | floor')
GRAND_TOTAL=$((TOTAL_TODO + TOTAL_IP + TOTAL_DONE + TOTAL_IGNORED))

printf "  ${DIM}"
printf '%.0s─' $(seq 1 "$TOTAL_W")
printf "${RST}\n"

printf "  ${BOLD}%-${W_A}s${RST}  %${W_T}s  %${W_I}s  %${W_D}s  %${W_IG}s\n" \
  "Total" "$TOTAL_TODO" "$TOTAL_IP" "$TOTAL_DONE" "$TOTAL_IGNORED"
echo ""
printf "  ${BOLD}%d pts${RST} ${DIM}in sprint${RST}" "$GRAND_TOTAL"

UNPOINTED=$(echo "$RESPONSE" | jq '[.issues[] | select(.fields.customfield_10026 == null)] | length')
if [[ "$UNPOINTED" -gt 0 ]]; then
  printf "  ${DIM}(%d unpointed)${RST}" "$UNPOINTED"
fi
echo ""
echo ""
