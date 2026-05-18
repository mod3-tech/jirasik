---
name: jirasik
description: Manage Jira tickets, sprints, comments, Confluence pages, and ad-hoc Jira API calls via jirasik CLI and jira-api.sh. Use when user mentions ticket IDs, sprint status, Confluence pages, or needs to read/write any Jira field.
---

# Jira & Confluence Management with jirasik

Use this skill proactively whenever the user mentions a Jira ticket ID (e.g., ERS-123), asks about sprint status, or references Confluence pages.

## CRITICAL: Always pass `-n` (no-banner)

Every `jirasik` CLI invocation MUST include `-n` / `--no-banner`. The ASCII banner wastes tokens and clutters output. No exceptions.

Note: the underlying scripts at `~/.jirasik/scripts/*.sh` do not print a banner — `-n` is only relevant to the `jirasik` wrapper in `bin/`.

## CLI Commands

```bash
jirasik -n ERS-123                          # Fetch ticket details
jirasik -n --sprint                         # View current sprint board
jirasik -n --todos                          # View sprint todos
jirasik -n --points                         # Sprint points summary
jirasik -n --move ERS-123                   # Move ticket (interactive)
jirasik -n --move ERS-123 "In Progress"     # Move ticket to specific status
jirasik -n --comments ERS-123               # View comments
jirasik -n --add-comment ERS-123 "text"     # Add comment
jirasik -n --wiki <URL|PAGE-ID>             # Fetch Confluence page
jirasik -n --open                           # Open Jira board in browser
```

## Ad-hoc Jira API via `jira-api.sh`

For one-off reads/writes not covered by CLI commands (setting points, changing assignee, editing arbitrary fields, JQL queries), use `jira-api.sh` directly. It handles auth, URL encoding, JSON validation, and error normalization.

```bash
JIRA_API=~/.jirasik/scripts/jira-api.sh
```

### Common operations

**Set story points:**
```bash
$JIRA_API PUT /issue/ERS-123 --data '{"fields":{"customfield_10026":5}}'
```

**Change assignee (to current user):**
```bash
ACCOUNT_ID=$($JIRA_API GET /myself --raw | jq -r .accountId)
$JIRA_API PUT /issue/ERS-123 --data "{\"fields\":{\"assignee\":{\"accountId\":\"$ACCOUNT_ID\"}}}"
```

**Change assignee (to someone else):**
```bash
~/.jirasik/scripts/search_users.sh "Jane Doe"
# Then assign with their accountId
$JIRA_API PUT /issue/ERS-123 --data '{"fields":{"assignee":{"accountId":"<id>"}}}'
```

**Set priority:**
```bash
$JIRA_API PUT /issue/ERS-123 --data '{"fields":{"priority":{"name":"High"}}}'
```

**Set epic link:**
```bash
$JIRA_API PUT /issue/ERS-123 --data '{"fields":{"customfield_10014":"ERS-100"}}'
```

**Edit summary/title:**
```bash
$JIRA_API PUT /issue/ERS-123 --data '{"fields":{"summary":"New title here"}}'
```

**Add/remove label:**
```bash
$JIRA_API PUT /issue/ERS-123 --data '{"update":{"labels":[{"add":"tech-debt"}]}}'
$JIRA_API PUT /issue/ERS-123 --data '{"update":{"labels":[{"remove":"tech-debt"}]}}'
```

**Read specific fields:**
```bash
$JIRA_API GET /issue/ERS-123 --query fields=summary,status,assignee,customfield_10026
```

**JQL search (NEVER use legacy /search — it was removed):**
```bash
$JIRA_API GET /search/jql --query 'jql=project=ERS AND status="In Progress"' --query fields=summary,status
```

**Agile API (boards, sprints):**
```bash
$JIRA_API GET /board --agile --query projectKeyOrId=ERS --query type=scrum
$JIRA_API GET /board/158/sprint --agile --query state=active
```

**Confluence API:**
```bash
$JIRA_API GET /content/12345 --wiki --query expand=body.storage
```

### Flags

| Flag | Effect |
|------|--------|
| `--raw` | Skip pretty-print (use when piping to `jq`) |
| `--agile` | Base path → `/rest/agile/1.0` |
| `--wiki` | Base path → `/wiki/rest/api` |
| `--query k=v` | URL query param (repeatable, auto-encoded) |
| `--data '{"json"}'` | JSON request body (inline) |
| `--data-file path` | JSON body from file (`-` for stdin) |

Default base: `/rest/api/3`. Absolute paths starting with `/rest/` or `/wiki/` pass through.

### Custom field IDs

| ID | Field |
|----|-------|
| `customfield_10014` | Epic Link |
| `customfield_10021` | Sprint (array; check `.state`) |
| `customfield_10026` | Story Points |

### Error shapes

All errors emit single-line JSON on stderr:

| Shape | Exit | Meaning |
|-------|------|---------|
| `{"error":"no_config"}` | 1 | `~/.jirasik/config` missing — run `setup.sh` |
| `{"error":"auth_failed","status":401}` | 2 | Session expired — re-auth via Firefox |
| `{"error":"not_found","status":404}` | 3 | Resource doesn't exist |
| `{"error":"http_client","status":4xx}` | 4 | Bad JQL, validation, etc. |
| `{"error":"http_server","status":5xx}` | 5 | Jira server error |
| `{"error":"removed_endpoint"}` | 6 | Used legacy `/search` — use `/search/jql` |
| `{"error":"bad_usage"}` | 64 | Script argument error |

### Auth error recovery

If `auth_failed` or `no_token`: start Firefox with `headless=false`, `profilePath=~/.jirasik/firefox-profile`, `startUrl=<JIRA_URL>`. User logs in manually. Close Firefox, retry.

## Safety rules

- **Reads** (GET): always safe, no confirmation needed.
- **Writes** (PUT/POST/DELETE): always show what will change and confirm with user first. Never auto-execute.
- **Git operations**: always show command and confirm first.

## Proactive usage

- User mentions ticket ID → fetch it with `jirasik -n <ID>`
- User asks about sprint → `jirasik -n --sprint` or `jirasik -n --todos`
- User references Confluence URL → `jirasik -n --wiki <URL>`
- User asks to set points/assignee/field on existing ticket → use `jira-api.sh PUT`
- Starting work on ticket → `jirasik -n --move <ID> "In Progress"`
- Work complete → add summary comment with `jirasik -n --add-comment <ID> "..."`
