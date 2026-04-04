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
    "r\t\(.key)\t\($en)\t\(.fields.summary)\t\($ps)"
  '
  echo "$DONE" | jq -r --argjson cache "$NEW_CACHE" '
    .[] |
    (.fields.customfield_10014 // "") as $ek |
    (if $ek == "" then "-" else ($cache[$ek] // $ek) end) as $en |
    (.fields.customfield_10026 // null) as $p |
    (if $p == null then "?" elif $p == 0 then "0" else ($p | floor | tostring) end) as $ps |
    "d\t\(.key)\t\($en)\t\(.fields.summary)\t\($ps)"
  '
)

# --- Column widths ---
W_T=6; W_E=4; W_TI=5; W_P=3
while IFS=$'\t' read -r _ ticket epic title pts; do
  [[ -z "$ticket" ]] && continue
  (( ${#ticket} > W_T )) && W_T=${#ticket}
  (( ${#epic} > W_E )) && W_E=${#epic}
  (( ${#title} > W_TI )) && W_TI=${#title}
  (( ${#pts} > W_P )) && W_P=${#pts}
done <<< "$ROWS"

TOTAL_W=$(( 2 + W_T + 2 + W_E + 2 + W_TI + 2 + W_P ))

# --- Table header ---
printf "  ${BOLD}%-${W_T}s  %-${W_E}s  %-${W_TI}s  %${W_P}s${RST}\n" \
  "Ticket" "Epic" "Title" "Pts"
printf "  ${DIM}"
printf '%.0s─' $(seq 1 "$TOTAL_W")
printf "${RST}\n"

# --- Table rows ---
PREV_TYPE=""
while IFS=$'\t' read -r type ticket epic title pts; do
  [[ -z "$ticket" ]] && continue
  if [[ "$type" == "d" && "$PREV_TYPE" == "r" ]]; then
    printf "  ${DIM}"
    printf '%.0s─' $(seq 1 "$TOTAL_W")
    printf "${RST}\n"
  fi
  PREV_TYPE="$type"
  if [[ "$type" == "d" ]]; then
    printf "  ${DIM}%-${W_T}s  %-${W_E}s  %-${W_TI}s  %${W_P}s${RST}  ${GREEN}✓${RST}\n" \
      "$ticket" "$epic" "$title" "$pts"
  else
    printf "  ${YELLOW}%-${W_T}s${RST}  ${CYAN}%-${W_E}s${RST}  %-${W_TI}s  %${W_P}s\n" \
      "$ticket" "$epic" "$title" "$pts"
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
