---
name: jirasik
description: Manage Jira tickets, sprints, comments, Confluence pages, and ad-hoc Jira API calls via jirasik CLI and jira-api.sh. Use when user mentions ticket IDs, sprint status, Confluence pages, or needs to read/write any Jira field.
---

# Jira & Confluence Management with jirasik

Use this skill proactively whenever the user mentions a Jira ticket ID (e.g., PROJ-123), asks about sprint status, or references Confluence pages.

## CRITICAL: Always pass `-n` (no-banner)

Every `jirasik` CLI invocation MUST include `-n` / `--no-banner`. The ASCII banner wastes tokens and clutters output. No exceptions.

Note: the underlying scripts at `~/.jirasik/scripts/*.sh` do not print a banner — `-n` is only relevant to the `jirasik` wrapper in `bin/`.

## CLI Commands

```bash
jirasik -n PROJ-123                          # Fetch ticket details
jirasik -n --sprint                         # View current sprint board
jirasik -n --todos                          # View sprint todos
jirasik -n --points                         # Sprint points summary
jirasik -n --move PROJ-123                   # Move ticket (interactive)
jirasik -n --move PROJ-123 "In Progress"     # Move ticket to specific status
jirasik -n --comments PROJ-123               # View comments
jirasik -n --add-comment PROJ-123 "text"     # Add comment
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
$JIRA_API PUT /issue/PROJ-123 --data '{"fields":{"customfield_10026":5}}'
```

**Change assignee (to current user):**
```bash
ACCOUNT_ID=$($JIRA_API GET /myself --raw | jq -r .accountId)
$JIRA_API PUT /issue/PROJ-123 --data "{\"fields\":{\"assignee\":{\"accountId\":\"$ACCOUNT_ID\"}}}"
```

**Change assignee (to someone else):**
```bash
~/.jirasik/scripts/search_users.sh "Jane Doe"
# Then assign with their accountId
$JIRA_API PUT /issue/PROJ-123 --data '{"fields":{"assignee":{"accountId":"<id>"}}}'
```

**Set priority:**
```bash
$JIRA_API PUT /issue/PROJ-123 --data '{"fields":{"priority":{"name":"High"}}}'
```

**Set epic link:**
```bash
$JIRA_API PUT /issue/PROJ-123 --data '{"fields":{"customfield_10014":"PROJ-100"}}'
```

**Edit summary/title:**
```bash
$JIRA_API PUT /issue/PROJ-123 --data '{"fields":{"summary":"New title here"}}'
```

**Add/remove label:**
```bash
$JIRA_API PUT /issue/PROJ-123 --data '{"update":{"labels":[{"add":"tech-debt"}]}}'
$JIRA_API PUT /issue/PROJ-123 --data '{"update":{"labels":[{"remove":"tech-debt"}]}}'
```

**Read specific fields:**
```bash
$JIRA_API GET /issue/PROJ-123 --query fields=summary,status,assignee,customfield_10026
```

**JQL search (NEVER use legacy /search — it was removed):**
```bash
$JIRA_API GET /search/jql --query 'jql=project=PROJ AND status="In Progress"' --query fields=summary,status
```

**Agile API (boards, sprints):**
```bash
$JIRA_API GET /board --agile --query projectKeyOrId=PROJ --query type=scrum
$JIRA_API GET /board/<BOARD-ID>/sprint --agile --query state=active
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

## CRITICAL: Comments & descriptions are ADF, never Markdown

Jira does **not** render Markdown. Any text body for a **comment** or a **description** must be an Atlassian Document Format (ADF) document, never a raw Markdown string. If you pass Markdown as a `text` node, Jira shows the literal `**`, backticks, `[](...)`, `-`, etc. — it does not format them.

This applies to **every** write path:
- The built-in `add_comment.sh` / `create_ticket.sh` already build ADF from plain text — pass them plain text, not Markdown.
- Any **ad-hoc** comment/description write via `jira-api.sh` (`POST /issue/KEY/comment`, `PUT /issue/KEY` setting `description`) MUST send a hand-built ADF doc. Never shove Markdown into a single `text` node.

ADF doc skeleton (a comment uses `{body: <doc>}`; a description sets `fields.description: <doc>`):

```json
{ "type": "doc", "version": 1, "content": [ <block nodes> ] }
```

**Plain paragraph(s)** — split on newlines, one paragraph per line:
```bash
CONTENT=$(printf '%s' "$TEXT" | jq -Rs '
  split("\n") | map(select(. != ""))
  | map({type:"paragraph", content:[{type:"text", text:.}]})')
PAYLOAD=$(jq -n --argjson c "$CONTENT" '{body:{type:"doc",version:1,content:$c}}')
echo "$PAYLOAD" | $JIRA_API POST /issue/PROJ-123/comment --data-file -
```

**Inline marks** (instead of Markdown):

| Want | ADF |
|------|-----|
| **bold** | `{"type":"text","text":"x","marks":[{"type":"strong"}]}` |
| *italic* | `{"type":"text","text":"x","marks":[{"type":"em"}]}` |
| `code` | `{"type":"text","text":"x","marks":[{"type":"code"}]}` |
| [link](url) | `{"type":"text","text":"x","marks":[{"type":"link","attrs":{"href":"https://..."}}]}` |

**Block nodes** (instead of Markdown):

```json
{"type":"heading","attrs":{"level":3},"content":[{"type":"text","text":"Heading"}]}
{"type":"codeBlock","attrs":{"language":"bash"},"content":[{"type":"text","text":"echo hi"}]}
{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"item"}]}]}]}
{"type":"orderedList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"step"}]}]}]}
```

Build these with `jq -n` (so text is safely JSON-escaped), validate the doc parses, then post via `--data` / `--data-file -`.

## Safety rules

- **Reads** (GET): always safe, no confirmation needed.
- **Writes** (PUT/POST/DELETE): always show what will change and confirm with user first. Never auto-execute.
- **Git operations**: always show command and confirm first.

## Moving tickets (casual phrasing → run the move, no confirmation)

When the user casually asks to move a ticket — "move to done", "move this to QA", "mark it done", "push it to in review", etc. — in a context where they're clearly talking about a Jira ticket, just **run the move workflow** via `~/.jirasik/scripts/transition.sh`. Do not ask the user to type `/move`, and do not reach for an ad-hoc `jira-api.sh` transition.

**Resolve the target ticket from context:**
- Exactly one ticket key (`[A-Z]+-[0-9]+`) established in the session → that's the ticket. The user will almost never restate the key.
- Zero or multiple keys in context → ask *which ticket* (this is the only ticket-selection prompt allowed).

**Match intent, don't confirm:**
- The user's word ("done", "QA", "in review") is intent, not an exact transition name. Map it to the real transition for that ticket's workflow (transition names are project-specific — use the names the API returns as source of truth).
- If the target isn't directly reachable, fast-forward through intermediate transitions automatically (see `commands/move.md` Step 6).
- **Never prompt for confirmation on a move.** Execute directly and show a summary of what happened (`<status A> → <status B> → ...`).
- The only interruptions allowed: (1) ambiguous ticket selection above, or (2) the move genuinely can't complete (no forward transition / loop detected) — report the failure and current status; that's an error report, not a confirmation gate.

## Branch & PR naming — keep it short

When proposing a branch name or a PR title, **aim for ≤50 characters total, including the `<TICKET-ID>-` prefix** (e.g. `PROJ-123-`). Favor a terse, readable slug: drop filler words ("the", "a", "fix for"), abbreviate where clear. A few characters over 50 is acceptable only when trimming further would hurt readability — never pad past it for completeness. Branch names follow the `<TICKET-ID>-<slugified-title>` pattern (no type prefix); PR titles can be prose but stay within the same budget.

## Authoring a PR (the "Testing" section is for QA)

This applies when the user asks to open/push a PR ("push this and make a PR", "open a PR", etc.). At that point you author the PR body from the work just done.

**ALWAYS use the repo's PR template — fill it, don't freeform.** Before writing the body:

1. **Locate the template** in the work repo (the repo you're creating the PR from, not jirasik). Check, in order:
   - `.github/pull_request_template.md` / `.github/PULL_REQUEST_TEMPLATE.md`
   - `PULL_REQUEST_TEMPLATE.md` / `docs/pull_request_template.md` (root or `docs/`)
   - `.github/PULL_REQUEST_TEMPLATE/` (a directory of multiple templates — if present, pick the best-fit one; ask the user only if it's genuinely ambiguous)
   - Case-insensitive; the file may be `.md` or have no extension.
2. **If a template exists:** read it and reproduce its **exact structure** — every heading, checklist, comment marker, and placeholder in the same order. Fill each section from the work done; never drop, rename, or reorder sections. Leave a section's placeholder/`N/A` only when it truly doesn't apply, and say why in one line. Resolve checklist items honestly (check what's actually done).
3. **If no template is found:** say so briefly, then fall back to a sensible default body (Summary / Changes / Testing).
4. **Pass the filled template explicitly** so GitHub doesn't substitute or discard it: write the body to a temp file and use `gh pr create --body-file <file>` (or `--body "..."`). Do **not** run a bare `gh pr create` that opens an editor or relies on server-side template injection — that's the failure mode where the template gets skipped.

The **Testing** section of that template is read by **QA, not developers** — write it for them (below).

**Audience:** a skilled computer user who is **not** a programmer, Linux user, or database expert. They can navigate the application's UI, follow precise steps, and notice when something looks wrong. They cannot read code, run shell/SQL commands, inspect logs, attach debuggers, or interpret stack traces. Never ask them to.

**QA is short-staffed — minimize their time and effort.** Optimize the Testing section to be the fastest correct path to verifying the change:

- **Steps through the app UI only.** Describe what to click/type/observe in the product, not what to run in a terminal or query in a database. If verification truly requires a non-UI step, flag it as needing a developer instead of writing it for QA.
- **Give concrete, ready-to-use inputs.** Exact values, sample data, accounts/test records, URLs/screens to start from — so QA doesn't have to figure out or fabricate them. Don't make them hunt.
- **State the expected result for each step** ("you should see X"), so a pass/fail is obvious without judgment calls.
- **Lead with the shortest happy-path check** that proves the fix/feature works; then list the few highest-value edge cases worth their limited time. Don't enumerate exhaustive permutations.
- **Note prerequisites once, up front** (which environment, feature flags, permissions/role, data setup) rather than scattering them.
- **Plain language.** No code identifiers, function/table/column names, env vars, file paths, or jargon. Refer to features by what the user sees in the UI.

If the change genuinely can't be verified through the UI (e.g. a backend-only refactor), say so plainly in the Testing section and direct it to a developer/automated tests rather than handing QA steps they can't perform.

## Proactive usage

- User mentions ticket ID → fetch it with `jirasik -n <ID>`
- User asks about sprint → `jirasik -n --sprint` or `jirasik -n --todos`
- User references Confluence URL → `jirasik -n --wiki <URL>`
- User asks to set points/assignee/field on existing ticket → use `jira-api.sh PUT`
- User casually asks to move/mark a ticket → run `transition.sh` directly (see "Moving tickets" above)
- Starting work on ticket → `jirasik -n --move <ID> "In Progress"`
- Work complete → add summary comment with `jirasik -n --add-comment <ID> "..."`
