#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

source "$SCRIPT_DIR/lib/colors.sh"

usage() {
  echo "Usage: create_confluence.sh <SPACE-KEY> <TITLE> [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  SPACE-KEY   Confluence space key (use get_spaces.sh to find one)"
  echo "  TITLE       Page title"
  echo ""
  echo "Options:"
  echo "  --body        Page body as plain text (newlines become paragraphs)"
  echo "  --body-file   Read body from a file ('-' for stdin)"
  echo "  --parent      Parent page ID (nests the new page under it)"
  echo "  --dry-run     Show payload without creating the page"
  echo ""
  echo "Examples:"
  echo "  create_confluence.sh PROJ \"Spike: auth options\" --body \"Findings...\""
  echo "  create_confluence.sh PROJ \"Spike: auth options\" --body-file notes.md --parent 12345"
  exit 1
}

SPACE_KEY="${1:-}"
TITLE="${2:-}"
if [[ -z "$SPACE_KEY" || -z "$TITLE" ]]; then
  usage
fi
shift 2

BODY_TEXT=""
BODY_FILE=""
PARENT_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --body)      BODY_TEXT="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --parent)    PARENT_ID="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    *)           echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -n "$BODY_FILE" ]]; then
  if [[ "$BODY_FILE" == "-" || "$BODY_FILE" == "@-" ]]; then
    BODY_TEXT="$(cat)"
  else
    [[ -f "$BODY_FILE" ]] || { echo "${RED}Body file not found:${RST} $BODY_FILE" >&2; exit 1; }
    BODY_TEXT="$(cat "$BODY_FILE")"
  fi
fi

# Escape HTML metacharacters, then wrap each non-empty line in a paragraph.
# Confluence storage format is XHTML, not Markdown.
_escape_html() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

BODY_STORAGE=""
if [[ -n "$BODY_TEXT" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    BODY_STORAGE+="<p>$(printf '%s' "$line" | _escape_html)</p>"$'\n'
  done <<< "$BODY_TEXT"
fi

PAYLOAD=$(jq -n \
  --arg space "$SPACE_KEY" \
  --arg title "$TITLE" \
  --arg body "$BODY_STORAGE" \
  --arg parent "$PARENT_ID" \
  '{
    type: "page",
    title: $title,
    space: { key: $space },
    body: { storage: { value: $body, representation: "storage" } }
  } + (if $parent != "" then { ancestors: [{ id: $parent }] } else {} end)')

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "${YELLOW}[DRY RUN]${RST} Would create Confluence page:"
  echo "  ${DIM}Space:${RST}  $SPACE_KEY"
  echo "  ${DIM}Title:${RST}  $TITLE"
  [[ -n "$PARENT_ID" ]] && echo "  ${DIM}Parent:${RST} $PARENT_ID"
  echo ""
  echo "${DIM}Payload:${RST}"
  echo "$PAYLOAD" | jq .
  exit 0
fi

if BODY=$("$JIRA_API" POST /content --wiki --data "$PAYLOAD" --raw); then
  PAGE_ID=$(echo "$BODY" | jq -r '.id')
  URL="$JIRA/wiki/spaces/$SPACE_KEY/pages/$PAGE_ID"
  echo ""
  echo "${GREEN}Created${RST} ${BOLD}${TITLE}${RST}"
  echo "  ${DIM}URL:${RST} $URL"
  echo "$PAGE_ID"
else
  echo "Failed to create Confluence page"
  exit 1
fi
