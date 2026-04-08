#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

EPIC_CACHE="$DIR/epic_cache.json"

# --- 0. Parse argument ---
ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo '{"error": "no_argument", "message": "Usage: fetch_ticket.sh <TICKET-KEY or URL>"}'
  exit 1
fi

# Extract ticket key from URL or use as-is
if [[ "$ARG" == http* ]]; then
  TICKET_KEY=$(echo "$ARG" | grep -oE '[A-Z]+-[0-9]+' | head -1)
else
  TICKET_KEY="$ARG"
fi

if [[ -z "$TICKET_KEY" ]]; then
  echo '{"error": "bad_argument", "message": "Could not extract ticket key from: '"$ARG"'"}'
  exit 1
fi

# --- 1. Fetch ticket ---
RESPONSE=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY?fields=summary,status,assignee,reporter,priority,customfield_10026,customfield_10021,customfield_10014,description,issuetype,parent")

check_auth "$RESPONSE" ".fields"

# --- 3. Resolve epic name ---
EPIC_KEY=$(echo "$RESPONSE" | jq -r '.fields.customfield_10014 // empty')
EPIC_NAME=""
if [[ -n "$EPIC_KEY" ]]; then
  if [[ -f "$EPIC_CACHE" ]]; then
    EPIC_NAME=$(jq -r --arg k "$EPIC_KEY" '.[$k] // empty' "$EPIC_CACHE")
  fi
  if [[ -z "$EPIC_NAME" ]]; then
    EPIC_NAME=$(curl -sL -b "tenant.session.token=$TOKEN" \
      "$JIRA/rest/api/3/issue/$EPIC_KEY?fields=summary" | jq -r '.fields.summary // "Unknown"')
    # Update cache
    if [[ -f "$EPIC_CACHE" ]]; then
      CACHE=$(cat "$EPIC_CACHE")
    else
      CACHE='{}'
    fi
    echo "$CACHE" | jq --arg k "$EPIC_KEY" --arg v "$EPIC_NAME" '. + {($k): $v}' > "$EPIC_CACHE"
  fi
fi

# --- 4. Format output ---
BOLD=$'\033[1m'
DIM=$'\033[2m'
RST=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'

KEY=$(echo "$RESPONSE" | jq -r '.key')
TYPE=$(echo "$RESPONSE" | jq -r '.fields.issuetype.name // "Unknown"')
TITLE=$(echo "$RESPONSE" | jq -r '.fields.summary // "No title"')
STATUS=$(echo "$RESPONSE" | jq -r '.fields.status.name // "Unknown"')
ASSIGNEE=$(echo "$RESPONSE" | jq -r '.fields.assignee.displayName // "Unassigned"')
REPORTER=$(echo "$RESPONSE" | jq -r '.fields.reporter.displayName // "Unknown"')
PRIORITY=$(echo "$RESPONSE" | jq -r '.fields.priority.name // "None"')
POINTS=$(echo "$RESPONSE" | jq -r '.fields.customfield_10026 // empty')
PARENT_KEY=$(echo "$RESPONSE" | jq -r '.fields.parent.key // empty')
PARENT_SUMMARY=$(echo "$RESPONSE" | jq -r '.fields.parent.fields.summary // empty')

# Sprint (active)
SPRINT=$(echo "$RESPONSE" | jq -r '[.fields.customfield_10021[]? | select(.state == "active") | .name] | first // "None"')

# Slugified branch name
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
BRANCH="$KEY-$SLUG"

echo ""
echo "${BOLD}${KEY}${RST} ${DIM}(${TYPE})${RST}"
echo "${BOLD}${TITLE}${RST}"
echo ""
printf "  ${DIM}%-12s${RST} %s\n" "Status" "$STATUS"
printf "  ${DIM}%-12s${RST} %s\n" "Assignee" "$ASSIGNEE"
printf "  ${DIM}%-12s${RST} %s\n" "Reporter" "$REPORTER"
printf "  ${DIM}%-12s${RST} %s\n" "Priority" "$PRIORITY"
printf "  ${DIM}%-12s${RST} %s\n" "Sprint" "$SPRINT"
if [[ -n "$POINTS" ]]; then
  printf "  ${DIM}%-12s${RST} %s\n" "Points" "$POINTS"
fi
if [[ -n "$EPIC_KEY" ]]; then
  printf "  ${DIM}%-12s${RST} %s (%s)\n" "Epic" "$EPIC_NAME" "$EPIC_KEY"
fi
if [[ -n "$PARENT_KEY" ]]; then
  printf "  ${DIM}%-12s${RST} %s - %s\n" "Parent" "$PARENT_KEY" "$PARENT_SUMMARY"
fi
echo ""
printf "  ${DIM}%-12s${RST} ${CYAN}%s${RST}\n" "Branch" "$BRANCH"
printf "  ${DIM}%-12s${RST} ${CYAN}%s${RST}\n" "URL" "$JIRA/browse/$KEY"
echo ""

# --- 5. Description ---
DESC=$(curl -sL -b "tenant.session.token=$TOKEN" \
  "$JIRA/rest/api/3/issue/$TICKET_KEY?fields=description" | jq -r '
    def indent(d): "  " * d;

    def apply_marks(txt; marks):
      reduce (marks // [])[] as $m (txt;
        if $m.type == "strong" then "**" + . + "**"
        elif $m.type == "em" then "*" + . + "*"
        elif $m.type == "code" then "`" + . + "`"
        elif $m.type == "strike" then "~~" + . + "~~"
        elif $m.type == "link" then "[" + . + "](" + ($m.attrs.href // "") + ")"
        elif $m.type == "underline" then . # no markdown equivalent, pass through
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

    if .fields.description == null then
      ""
    else
      reduce .fields.description.content[] as $block (""; . + fmt($block; 0))
    end
  ' 2>/dev/null)

if [[ -n "$DESC" ]]; then
  echo "${DIM}--- Description ---${RST}"
  echo "$DESC" | glow
  echo ""
fi
