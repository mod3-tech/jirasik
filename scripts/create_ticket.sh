#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/auth.sh"

export JIRA TOKEN
export JIRASIK_SKIP_AUTH_BOOTSTRAP=1
JIRA_API="$SCRIPT_DIR/jira-api.sh"

source "$SCRIPT_DIR/lib/colors.sh"

usage() {
  echo "Usage: create_ticket.sh <PROJECT-KEY> <TITLE> <ISSUE-TYPE> [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  PROJECT-KEY   Jira project key (e.g., PROG, DEV)"
  echo "  TITLE         Ticket title"
  echo "  ISSUE-TYPE    Task, Bug, Story, Epic, etc."
  echo ""
  echo "Options:"
  echo "  --desc        Brief 1-2 sentence description"
  echo "  --details     Additional details, steps, links"
  echo "  --priority    Priority: Highest, High, Medium, Low, Lowest"
  echo "  --assignee    Assignee display name or email"
  echo "  --parent      Parent ticket key (e.g., PROG-100)"
  echo "  --sprint      Sprint ID (use get_sprints.sh to find IDs)"
  echo "  --dry-run     Show payload without creating the ticket"
  echo ""
  echo "Examples:"
  echo "  create_ticket.sh PROJ \"Login broken\" Bug"
  echo "  create_ticket.sh PROJ \"Login broken\" Bug --priority High --parent PROJ-100"
  exit 1
}

# --- Parse required positional args ---
PROJECT_KEY="${1:-}"
TITLE="${2:-}"
ISSUE_TYPE="${3:-}"

if [[ -z "$PROJECT_KEY" || -z "$TITLE" || -z "$ISSUE_TYPE" ]]; then
  usage
fi
shift 3

# --- Parse optional flags ---
SHORT_DESC=""
DETAILS=""
PRIORITY=""
ASSIGNEE=""
PARENT_KEY=""
SPRINT_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --desc)     SHORT_DESC="$2"; shift 2 ;;
    --details)  DETAILS="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --assignee) ASSIGNEE="$2"; shift 2 ;;
    --parent)   PARENT_KEY="$2"; shift 2 ;;
    --sprint)   SPRINT_ID="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    *)          echo "Unknown option: $1"; usage ;;
  esac
done

CONTENT='[]'
if [[ -n "$SHORT_DESC" ]]; then
  CONTENT=$(jq -n --arg v "$SHORT_DESC" '[{type: "paragraph", content: [{type: "text", text: $v}]}]')
fi

if [[ -n "$DETAILS" ]]; then
  CONTENT=$(jq -n --argjson content "$CONTENT" --arg details "$DETAILS" '
    $content + [
      {type: "heading", attrs: {level: 3}, content: [{type: "text", text: "Details"}]},
      {type: "paragraph", content: [{type: "text", text: $details}]}
    ]
  ')
fi

ACCOUNT_ID=""
if [[ -n "$ASSIGNEE" ]]; then
  ACCOUNT_ID=$("$JIRA_API" GET /users/search --raw \
    --query "query=$ASSIGNEE" --query maxResults=1 \
    | jq -r '.[] | select(.accountType == "atlassian") | .accountId // empty')
fi

PAYLOAD=$(jq -n \
  --arg key "$PROJECT_KEY" \
  --arg title "$TITLE" \
  --arg type "$ISSUE_TYPE" \
  --argjson content "$CONTENT" \
  --arg priority "$PRIORITY" \
  --arg accountId "$ACCOUNT_ID" \
  --arg parent "$PARENT_KEY" \
  --arg sprint "$SPRINT_ID" \
  '{
    fields: {
      project: { key: $key },
      summary: $title,
      issuetype: { name: $type },
      description: {
        type: "doc",
        version: 1,
        content: $content
      },
      priority: (if $priority != "" then {name: $priority} else null end),
      assignee: (if $accountId != "" then {accountId: $accountId} else null end),
      parent: (if $parent != "" then {key: $parent} else null end),
      customfield_10021: (if $sprint != "" then ($sprint | tonumber) else null end)
    }
  }')

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "${YELLOW}[DRY RUN]${RST} Would create ticket:"
  echo "  ${DIM}Project:${RST}    $PROJECT_KEY"
  echo "  ${DIM}Type:${RST}       $ISSUE_TYPE"
  echo "  ${DIM}Title:${RST}      $TITLE"
  [[ -n "$SHORT_DESC" ]] && echo "  ${DIM}Desc:${RST}       $SHORT_DESC"
  [[ -n "$DETAILS" ]]    && echo "  ${DIM}Details:${RST}    $DETAILS"
  [[ -n "$PRIORITY" ]]   && echo "  ${DIM}Priority:${RST}   $PRIORITY"
  [[ -n "$ASSIGNEE" ]]   && echo "  ${DIM}Assignee:${RST}   $ASSIGNEE (accountId: ${ACCOUNT_ID:-not found})"
  [[ -n "$PARENT_KEY" ]] && echo "  ${DIM}Parent:${RST}     $PARENT_KEY"
  [[ -n "$SPRINT_ID" ]]  && echo "  ${DIM}Sprint:${RST}     $SPRINT_ID"
  echo ""
  echo "${DIM}Payload:${RST}"
  echo "$PAYLOAD" | jq .
  exit 0
fi

if BODY=$("$JIRA_API" POST /issue --data "$PAYLOAD" --raw); then
  KEY=$(echo "$BODY" | jq -r '.key')
  URL="$JIRA/browse/$KEY"
  echo ""
  echo "${GREEN}Created${RST} ${BOLD}${KEY}${RST} - ${TITLE}"
  echo "  ${DIM}URL:${RST} $URL"
  echo "$KEY"
else
  echo "Failed to create ticket"
  exit 1
fi
