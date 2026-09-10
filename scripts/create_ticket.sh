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
  echo "  --ac          Acceptance criteria (dedicated field, else description)"
  echo "  --ac-field    Explicit acceptance-criteria field ID (else auto-detected)"
  echo "  --points      Story points (Fibonacci)"
  echo "  --points-field Story-points field ID (default: customfield_10026)"
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
AC_TEXT=""
AC_FIELD_ID="${JIRASIK_AC_FIELD:-}"
POINTS=""
POINTS_FIELD_ID="${JIRASIK_POINTS_FIELD:-customfield_10026}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --desc)         SHORT_DESC="$2"; shift 2 ;;
    --details)      DETAILS="$2"; shift 2 ;;
    --ac)           AC_TEXT="$2"; shift 2 ;;
    --ac-field)     AC_FIELD_ID="$2"; shift 2 ;;
    --points)       POINTS="$2"; shift 2 ;;
    --points-field) POINTS_FIELD_ID="$2"; shift 2 ;;
    --priority)     PRIORITY="$2"; shift 2 ;;
    --assignee)     ASSIGNEE="$2"; shift 2 ;;
    --parent)       PARENT_KEY="$2"; shift 2 ;;
    --sprint)       SPRINT_ID="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    *)              echo "Unknown option: $1"; usage ;;
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

# --- Acceptance criteria ---
# Prefer the instance's dedicated AC field; fall back to the description.
AC_EXTRA=""
if [[ -n "$AC_TEXT" ]]; then
  if [[ -z "$AC_FIELD_ID" ]]; then
    AC_MATCH=$("$JIRA_API" GET /field --raw \
      | jq -c '[.[] | select((.name // "") | ascii_downcase | contains("acceptance"))] | first // empty')
    if [[ -n "$AC_MATCH" ]]; then
      AC_FIELD_ID=$(echo "$AC_MATCH" | jq -r '.id')
      AC_FIELD_TYPE=$(echo "$AC_MATCH" | jq -r '.schema.type // ""')
    fi
  else
    AC_FIELD_TYPE=$("$JIRA_API" GET /field --raw \
      | jq -r --arg id "$AC_FIELD_ID" '[.[] | select(.id == $id) | .schema.type][0] // ""')
  fi

  if [[ -n "$AC_FIELD_ID" ]]; then
    # Rich-text fields expect ADF; plain text fields expect a string.
    if [[ "${AC_FIELD_TYPE:-}" == "doc" ]]; then
      AC_VALUE=$(jq -n --arg t "$AC_TEXT" '
        {type: "doc", version: 1,
         content: ($t | split("\n") | map(select(. != ""))
                   | map({type: "paragraph", content: [{type: "text", text: .}]}))}')
    else
      AC_VALUE=$(jq -n --arg t "$AC_TEXT" '$t')
    fi
    AC_EXTRA=$(jq -n --arg id "$AC_FIELD_ID" --argjson v "$AC_VALUE" '{($id): $v}')
  else
    CONTENT=$(jq -n --argjson content "$CONTENT" --arg t "$AC_TEXT" '
      $content + [
        {type: "heading", attrs: {level: 3}, content: [{type: "text", text: "Acceptance Criteria"}]},
        {type: "paragraph", content: [{type: "text", text: $t}]}
      ]')
  fi
fi

# --- Story points ---
EXTRA='{}'
[[ -n "$AC_EXTRA" ]] && EXTRA=$(jq -n --argjson e "$EXTRA" --argjson a "$AC_EXTRA" '$e + $a')

if [[ -n "$POINTS" ]]; then
  if ! [[ "$POINTS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "${RED}Invalid --points:${RST} $POINTS (expected a number)" >&2
    exit 1
  fi
  EXTRA=$(jq -n --argjson e "$EXTRA" --arg f "$POINTS_FIELD_ID" --argjson p "$POINTS" '$e + {($f): $p}')
fi

ACCOUNT_ID=""
if [[ -n "$ASSIGNEE" ]]; then
  # /user/search (singular) — /users/search returns unfiltered results on
  # Jira Cloud regardless of query, leading to wrong-user assignment.
  USER_RESULTS=$("$JIRA_API" GET /user/search --raw \
    --query "query=$ASSIGNEE" --query maxResults=10 \
    | jq -c '[.[]
        | select((.accountType // "atlassian") == "atlassian")
        | select(.active != false)
        | {accountId, displayName, emailAddress: (.emailAddress // "")}]')

  USER_COUNT=$(echo "$USER_RESULTS" | jq 'length')

  if [[ "$USER_COUNT" == "0" ]]; then
    echo "${RED}Assignee lookup failed:${RST} no active user matched \"$ASSIGNEE\"" >&2
    echo "Try: ${DIM}~/.jirasik/scripts/search_users.sh \"$ASSIGNEE\"${RST}" >&2
    exit 1
  fi

  # Prefer exact email match when the query looks like an email
  if [[ "$ASSIGNEE" == *"@"* ]]; then
    ACCOUNT_ID=$(echo "$USER_RESULTS" \
      | jq -r --arg q "$ASSIGNEE" 'map(select((.emailAddress // "") | ascii_downcase == ($q | ascii_downcase))) | .[0].accountId // empty')
  fi

  # Fall back to single-result match
  if [[ -z "$ACCOUNT_ID" ]]; then
    if [[ "$USER_COUNT" == "1" ]]; then
      ACCOUNT_ID=$(echo "$USER_RESULTS" | jq -r '.[0].accountId')
    else
      echo "${RED}Assignee lookup ambiguous:${RST} \"$ASSIGNEE\" matched $USER_COUNT users." >&2
      echo "$USER_RESULTS" | jq -r '.[] | "  \(.displayName) <\(.emailAddress)>  (\(.accountId))"' >&2
      echo "Rerun with the exact email or accountId, or skip --assignee and assign post-creation." >&2
      exit 1
    fi
  fi
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
  --argjson extra "$EXTRA" \
  '{
    fields: ({
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
    } + $extra)
  }')

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "${YELLOW}[DRY RUN]${RST} Would create ticket:"
  echo "  ${DIM}Project:${RST}    $PROJECT_KEY"
  echo "  ${DIM}Type:${RST}       $ISSUE_TYPE"
  echo "  ${DIM}Title:${RST}      $TITLE"
  [[ -n "$SHORT_DESC" ]] && echo "  ${DIM}Desc:${RST}       $SHORT_DESC"
  [[ -n "$DETAILS" ]]    && echo "  ${DIM}Details:${RST}    $DETAILS"
  [[ -n "$AC_TEXT" ]]    && echo "  ${DIM}AC:${RST}         $AC_TEXT${AC_FIELD_ID:+ (field: $AC_FIELD_ID)}"
  [[ -n "$POINTS" ]]     && echo "  ${DIM}Points:${RST}     $POINTS${POINTS_FIELD_ID:+ (field: $POINTS_FIELD_ID)}"
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
