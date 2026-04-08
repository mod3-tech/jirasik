#!/usr/bin/env bash
# Shared issue table display — sourced by other scripts
# Expects: $ISSUES (JSON with .issues[]), $TITLE, $SUBTITLE
# Expects auth.sh already sourced (provides $TOKEN, $JIRA, $DIR)

EPIC_CACHE="$DIR/epic_cache.json"

# --- Resolve epics ---
if [[ -f "$EPIC_CACHE" ]]; then
  CACHE=$(cat "$EPIC_CACHE")
else
  CACHE='{}'
fi

EPIC_KEYS=$(echo "$ISSUES" | jq -r '[.issues[].fields.customfield_10014 // empty] | unique | .[]')

NEW_CACHE="$CACHE"
for key in $EPIC_KEYS; do
  cached=$(echo "$NEW_CACHE" | jq -r --arg k "$key" '.[$k] // empty')
  if [[ -z "$cached" ]]; then
    name=$(curl -sL -b "tenant.session.token=$TOKEN" \
      "$JIRA/rest/api/3/issue/$key?fields=summary" | jq -r '.fields.summary // "Unknown"')
    NEW_CACHE=$(echo "$NEW_CACHE" | jq --arg k "$key" --arg v "$name" '. + {($k): $v}')
  fi
done
echo "$NEW_CACHE" > "$EPIC_CACHE"

# --- Header ---
BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
BLUE=$'\033[34m'
MAGENTA=$'\035[35m'

PURPLE=$'\033[38;5;141m'

status_color() {
  local status_name="$1"
  local status_key="$2"
  case "$status_key" in
    done) echo "$GREEN" ;;
    new)
      local lower_status
      lower_status=$(echo "$status_name" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_status" == *"ready"* || "$lower_status" == *"review"* || "$lower_status" == *"await"* || "$lower_status" == *"wait"* ]]; then
        echo "$PURPLE"
      else
        echo "$RST"
      fi
      ;;
    indeterminate)
      local lower_status
      lower_status=$(echo "$status_name" | tr '[:upper:]' '[:lower:]')
      if [[ "$lower_status" == *"hold"* ]]; then
        echo "$YELLOW"
      elif [[ "$lower_status" == *"review"* || "$lower_status" == *"await"* || "$lower_status" == *"wait"* ]]; then
        echo "$PURPLE"
      else
        echo "$BLUE"
      fi
      ;;
    *) echo "$RST" ;;
  esac
}

echo ""
echo "${BOLD}${TITLE}${RST}"
echo "${DIM}${SUBTITLE}${RST}"
echo ""

# --- Split remaining vs done ---
REMAINING=$(echo "$ISSUES" | jq -c '[.issues[] | select(.fields.status.statusCategory.name != "Done")]')
DONE=$(echo "$ISSUES" | jq -c '[.issues[] | select(.fields.status.statusCategory.name == "Done")]')

# --- Generate TSV rows ---
ROWS=$(
  echo "$REMAINING" | jq -r --argjson cache "$NEW_CACHE" '
    .[] |
    (.fields.customfield_10014 // "") as $ek |
    (if $ek == "" then "-" else ($cache[$ek] // $ek) end) as $en |
    (.fields.customfield_10026 // null) as $p |
    (if $p == null then "?" elif $p == 0 then "0" else ($p | floor | tostring) end) as $ps |
    (.fields.status.name // "-") as $st |
    "r\t\(.key)\t\($en)\t\(.fields.summary)\t\($ps)\t\($st)"
  '
  echo "$DONE" | jq -r --argjson cache "$NEW_CACHE" '
    .[] |
    (.fields.customfield_10014 // "") as $ek |
    (if $ek == "" then "-" else ($cache[$ek] // $ek) end) as $en |
    (.fields.customfield_10026 // null) as $p |
    (if $p == null then "?" elif $p == 0 then "0" else ($p | floor | tostring) end) as $ps |
    (.fields.status.name // "-") as $st |
    "d\t\(.key)\t\($en)\t\(.fields.summary)\t\($ps)\t\($st)"
  '
)

# --- Column widths ---
W_T=6; W_E=4; W_TI=5; W_P=3; W_S=8
while IFS=$'\t' read -r _ ticket epic title pts status_name; do
  [[ -z "$ticket" ]] && continue
  (( ${#ticket} > W_T )) && W_T=${#ticket}
  (( ${#epic} > W_E )) && W_E=${#epic}
  (( ${#title} > W_TI )) && W_TI=${#title}
  (( ${#pts} > W_P )) && W_P=${#pts}
  (( ${#status_name} > W_S )) && W_S=${#status_name}
done <<< "$ROWS"

TOTAL_W=$(( 2 + W_T + 2 + W_E + 2 + W_TI + 2 + W_P + 2 + W_S ))

# --- Table header ---
printf "  ${BOLD}%-${W_T}s  %-${W_E}s  %-${W_TI}s  %${W_P}s  %-${W_S}s${RST}\n" \
  "Ticket" "Epic" "Title" "Pts" "Status"
printf "  ${DIM}"
printf '%.0s─' $(seq 1 "$TOTAL_W")
printf "${RST}\n"

# --- Table rows ---
PREV_TYPE=""
while IFS=$'\t' read -r type ticket epic title pts status_name; do
  [[ -z "$ticket" ]] && continue
  if [[ "$type" == "d" && "$PREV_TYPE" == "r" ]]; then
    printf "  ${DIM}"
    printf '%.0s─' $(seq 1 "$TOTAL_W")
    printf "${RST}\n"
  fi
  PREV_TYPE="$type"
  ST_KEY=$(echo "$ISSUES" | jq -r --arg k "$ticket" '.issues[] | select(.key == $k) | .fields.status.statusCategory.key // "unknown"')
  ST_NAME=$(echo "$ISSUES" | jq -r --arg k "$ticket" '.issues[] | select(.key == $k) | .fields.status.name // "Unknown"')
  CLR=$(status_color "$ST_NAME" "$ST_KEY")
  if [[ "$type" == "d" ]]; then
    printf "  ${DIM}%-${W_T}s  %-${W_E}s  %-${W_TI}s  %${W_P}s  ${GREEN}%-${W_S}s${RST}\n" \
      "$ticket" "$epic" "$title" "$pts" "$status_name ✓"
  else
    printf "  ${YELLOW}%-${W_T}s${RST}  ${CYAN}%-${W_E}s${RST}  %-${W_TI}s  %${W_P}s  ${CLR}%-${W_S}s${RST}\n" \
      "$ticket" "$epic" "$title" "$pts" "$status_name"
  fi
done <<< "$ROWS"
echo ""

# --- Summary ---
TODO_PTS=$(echo "$REMAINING" | jq '[.[].fields.customfield_10026 // 0] | add // 0 | floor')
DONE_PTS=$(echo "$DONE" | jq '[.[].fields.customfield_10026 // 0] | add // 0 | floor')
TOTAL_PTS=$((TODO_PTS + DONE_PTS))
UNPOINTED=$(echo "$ISSUES" | jq '[.issues[] | select(.fields.customfield_10026 == null)] | length')

printf "  ${YELLOW}${BOLD}%d pts todo${RST} ${DIM}|${RST} ${GREEN}${BOLD}%d pts done${RST} ${DIM}|${RST} ${BOLD}%d pts total${RST}" \
  "$TODO_PTS" "$DONE_PTS" "$TOTAL_PTS"
if [[ "$UNPOINTED" -gt 0 ]]; then
  printf " ${DIM}(%d unpointed)${RST}" "$UNPOINTED"
fi
echo ""
echo ""
