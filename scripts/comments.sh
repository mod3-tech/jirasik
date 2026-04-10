#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'

# --- Parse argument ---
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo "Usage: comments.sh <TICKET-KEY or URL>"
  exit 1
fi

if [[ "$ARG" == http* ]]; then
  TICKET_KEY=$(echo "$ARG" | grep -oE '[A-Z]+-[0-9]+' | head -1)
else
  TICKET_KEY="$ARG"
fi

if [[ -z "$TICKET_KEY" ]]; then
  echo "Could not extract ticket key from: $ARG"
  exit 1
fi

# --- Fetch comments ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY/comment?orderBy=-created&maxResults=20")

check_auth "$RESPONSE" ".comments"

COUNT=$(echo "$RESPONSE" | jq '.comments | length')

if [[ "$COUNT" -eq 0 ]]; then
  echo ""
  echo "${DIM}No comments on ${TICKET_KEY}${RST}"
  echo ""
  exit 0
fi

TOTAL=$(echo "$RESPONSE" | jq '.total')

# --- ADF to markdown ---
ADF_FILTER='
  def indent(d): "  " * d;

  def apply_marks(txt; marks):
    reduce (marks // [])[] as $m (txt;
      if $m.type == "strong" then "**" + . + "**"
      elif $m.type == "em" then "*" + . + "*"
      elif $m.type == "code" then "`" + . + "`"
      elif $m.type == "strike" then "~~" + . + "~~"
      elif $m.type == "link" then "[" + . + "](" + ($m.attrs.href // "") + ")"
      elif $m.type == "underline" then .
      else .
      end
    );

  def fmt(b; d):
    if b.type == "text" then
      apply_marks(b.text; b.marks)
    elif b.type == "hardBreak" then
      "\n" + indent(d)
    elif b.type == "paragraph" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "\n"
    elif b.type == "bulletList" then
      (reduce b.content[] as $li (""; . + indent(d) + "- " + (reduce ($li.content // [])[] as $c (""; . + fmt($c; d + 1))) + "\n"))
    elif b.type == "orderedList" then
      (reduce range(0; b.content | length) as $i (
        "";
        . + indent(d) + "\($i + 1). " + (reduce (b.content[$i].content // [])[] as $c (""; . + fmt($c; d + 1))) + "\n"
      ))
    elif b.type == "listItem" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "rule" then
      "\n---\n"
    elif b.type == "heading" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "\n"
    elif b.type == "codeBlock" then
      "```" + (b.attrs.language // "") + "\n" + (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "```\n"
    elif b.type == "blockquote" then
      (reduce (b.content // [])[] as $c (""; . + "> " + fmt($c; d)))
    elif b.type == "panel" then
      "[" + (b.attrs.panelType // "info") + "] " + (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "inlineCard" then
      (b.attrs.url // "[link]")
    elif b.type == "blockCard" then
      (b.attrs.url // "[link]") + "\n"
    elif b.type == "mention" then
      "@" + (b.attrs.text // b.attrs.id // "unknown")
    elif b.type == "emoji" then
      (b.attrs.shortName // b.attrs.text // "")
    elif b.type == "status" then
      "[" + (b.attrs.text // "status") + "]"
    elif b.type == "date" then
      (b.attrs.timestamp // "")
    elif b.type == "expand" then
      (b.attrs.title // "") + "\n" + (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "table" then
      (reduce (b.content // [])[] as $row (""; . + fmt($row; d))) + "\n"
    elif b.type == "tableRow" then
      "| " + (reduce (b.content // [])[] as $cell (""; . + fmt($cell; d) + " | ")) + "\n"
    elif b.type == "tableHeader" then
      "**" + (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "**"
    elif b.type == "tableCell" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "mediaSingle" or b.type == "mediaGroup" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "media" then
      "[attachment: " + (b.attrs.alt // b.attrs.id // "media") + "]\n"
    elif b.content != null then
      (reduce b.content[] as $c (""; . + fmt($c; d)))
    else
      ""
    end;

  if .body == null then
    ""
  else
    reduce .body.content[] as $block (""; . + fmt($block; 0))
  end
'

# --- Display ---
echo ""
echo "${BOLD}Comments on ${TICKET_KEY}${RST} ${DIM}(${COUNT} of ${TOTAL})${RST}"
echo ""

echo "$RESPONSE" | jq -c '.comments[]' | while IFS= read -r comment; do
  AUTHOR=$(echo "$comment" | jq -r '.author.displayName // "Unknown"')
  CREATED=$(echo "$comment" | jq -r '.created // ""')

  # Format date: 2024-01-15T10:30:00.000+0000 -> Jan 15, 2024 10:30
  if [[ -n "$CREATED" ]]; then
    DATE_FMT=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${CREATED%%.*}" "+%b %-d, %Y %H:%M" 2>/dev/null || echo "$CREATED")
  else
    DATE_FMT=""
  fi

  BODY=$(echo "$comment" | jq -r "$ADF_FILTER" 2>/dev/null)

  printf "  ${YELLOW}%s${RST} ${DIM}%s${RST}\n" "$AUTHOR" "$DATE_FMT"
  if [[ -n "$BODY" ]]; then
    echo "$BODY" | sed 's/^/    /'
  fi
  echo ""
done
