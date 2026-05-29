# AGENTS.md

## Developer Commands

Run non-interactive scripts from `scripts/` only. `setup.sh` + `./bin/jirasik` require TTY — do not auto-run.

**If you do invoke `jirasik` (the CLI wrapper) at all, always pass `-n` / `--no-banner`.** The ASCII banner is purely decorative and wastes context. Scripts under `~/.jirasik/scripts/` don't emit a banner — no flag needed there.

```bash
jirasik -n PROG-123        # Fetch ticket
jirasik -n -t              # Sprint todos
jirasik -n -s              # View sprint
jirasik -n -m PROG-123 "In Progress"  # Move ticket
jirasik -n -c PROG-123      # View comments
jirasik -n -a PROG-123 "text"  # Add comment
jirasik -n -w <URL|PAGE-ID>  # Fetch Confluence page
jirasik -n -p              # Sprint points
jirasik -n -o              # Open Jira in browser
```

## Architecture

- Scripts → `~/.jirasik/scripts/`
- OpenCode commands → `{PROJECT_DIR}/.opencode/commands/` (multi-project via `~/.jirasik/projects`)
- Auth: Firefox SQLite cookie DB
- Tests: `./tests/bats/bin/bats tests/`
- Pure bash/CLI — no lint, no build

## Testing

After modifying `scripts/lib/adf.sh`, run tests:

```bash
./tests/bats/bin/bats tests/adf.bats
```

After modifying `scripts/jira-api.sh`, run tests:

```bash
./tests/bats/bin/bats tests/jira-api.bats
```

All tests pass before committing.

## Ad-hoc Jira API calls

When you need data that isn't covered by an existing script (e.g. custom fields, arbitrary endpoints, one-off writes), use `scripts/jira-api.sh` instead of hand-rolling `curl`. It reuses `auth.sh` for authentication, URL-encodes query params, validates JSON bodies, and normalizes errors to JSON shapes the LLM can pattern-match.

All of the built-in scripts (`fetch_ticket`, `fetch_todos`, `sprint-view`, `transition`, `comments`, `add_comment`, `create_ticket`, `points`, `search_*`, `get_*`, `display-issues`, `fetch_confluence`) route their HTTP through `jira-api.sh`. When writing a new script, follow the same pattern: `source auth.sh`, then `export JIRA TOKEN JIRASIK_SKIP_AUTH_BOOTSTRAP=1` and call `"$SCRIPT_DIR/jira-api.sh" METHOD /path --raw --query k=v ...`. The `--raw` flag skips pretty-printing when piping to `jq`. The only intentional raw-curl holdouts are `auth.sh` itself (bootstrap / token validation) and `fetch_confluence.sh` short-link redirect chasing.

```bash
# Read an issue
~/.jirasik/scripts/jira-api.sh GET /issue/PROG-123

# Read with selected fields (no manual URL encoding)
~/.jirasik/scripts/jira-api.sh GET /issue/PROG-123 --query fields=summary,status,description

# JQL search — ALWAYS use /search/jql (the legacy /search was removed, CHANGE-2046)
~/.jirasik/scripts/jira-api.sh GET /search/jql --query 'jql=project=PROG' --query fields=summary

# Post a comment (JSON body from stdin)
echo "$PAYLOAD" | ~/.jirasik/scripts/jira-api.sh POST /issue/PROG-123/comment --data-file -

# Set a custom field (story points)
~/.jirasik/scripts/jira-api.sh PUT /issue/PROG-123 --data '{"fields":{"customfield_10026":5}}'

# Agile API (boards, sprints)
~/.jirasik/scripts/jira-api.sh GET /board --agile --query projectKeyOrId=PROG --query type=scrum

# Confluence
~/.jirasik/scripts/jira-api.sh GET /content/12345 --wiki --query expand=body.storage
```

Default base is `/rest/api/3`. Use `--agile` for `/rest/agile/1.0`, `--wiki` for `/wiki/rest/api`. Absolute paths starting with `/rest/` or `/wiki/` are passed through untouched.

### Useful custom field IDs

- `customfield_10014` — Epic Link
- `customfield_10021` — Sprint (array of sprint objects; check `.state`)
- `customfield_10026` — Story Points

### Error shapes (emitted on stderr as single-line JSON)

| Shape | Exit | When |
|-------|------|------|
| `{"error":"no_config",...}` | 1 | `~/.jirasik/config` missing — tell user to run `setup.sh` |
| `{"error":"auth_failed","status":401,...}` | 2 | Session expired — re-auth via Firefox (see `commands/jira.md`) |
| `{"error":"not_found","path":"...","status":404,...}` | 3 | Resource doesn't exist |
| `{"error":"http_client","status":4xx,...}` | 4 | Other 4xx (bad JQL, validation, etc.) |
| `{"error":"http_server","status":5xx,...}` | 5 | Jira server error |
| `{"error":"removed_endpoint",...}` | 6 | You tried to hit legacy `/search`; use `/search/jql` |
| `{"error":"bad_usage","message":"..."}` | 64 | Argument error in the script call itself |

On success, the response body is pretty-printed JSON on stdout. Use `--raw` to skip the `jq .` pretty-print.

## Commands Reference

| OpenCode | CLI | Description |
|----------|-----|-------------|
| `/jira TICKET` | `jirasik -n TICKET` | Ticket details |
| `/move TICKET` | `jirasik -n -m TICKET` | Move to status |
| `/todos` | `jirasik -n -t` | Sprint tickets |
| — | `jirasik -n -c TICKET` | View comments |
| — | `jirasik -n -a TICKET "text"` | Add comment |
| `/create-ticket` | — | Create a new Jira ticket |
| `/confluence URL` | `jirasik -n -w URL\|PAGE-ID` | Fetch Confluence page |
| `/pr URL` | — | GitHub PR quick critical-issue review (Jira-aware; can approve on request) |
| `/pr-full URL` | — | GitHub PR thorough review (Jira-aware; can approve on request) |
| `/review [RANGE]` | — | Pre-PR self-review of current branch |
| `/review-deep [RANGE]` | — | Deep pre-PR review (3 passes + vetter, findings grouped by severity) |

## PR & review command behaviors

The review commands carry behavior beyond a plain diff read. Keep these in sync with `agents/pr-review.md`, `agents/pr-review-full.md`, `agents/review-vetter.md`, and the matching `commands/*.md`.

### Jira ticket context (`/pr`, `/pr-full`)

Both PR review agents gather linked Jira context before analyzing the diff:

- Scan the PR title, description, branch name, and commit messages for Jira keys (`[A-Z]+-[0-9]+`), dedupe, and discard obvious non-tickets (`UTF-8`, `SHA-1`, etc.).
- For each plausible key, fetch the description (`~/.jirasik/scripts/fetch_ticket.sh <KEY>`) and comments (`~/.jirasik/scripts/comments.sh <KEY>`). These three scripts (`fetch_ticket.sh`, `comments.sh`, `jira-api.sh`) are allowlisted in each agent's `permission.bash`.
- Degrade gracefully: `auth_failed`/`not_found`/not-installed never abort the review — note that context was unavailable and continue.
- The diff is reviewed **in light of** PR + ticket context. Context can suppress a finding **only** when the discussion directly addresses that specific concern; intent never excuses a genuine correctness/security bug. Resolved findings are listed (not silently dropped), and the output opens with a cited **Context** summary of the snippets that informed the review.

### Approve on explicit request (`/pr`, `/pr-full`)

Approval is opt-in and triggered only by explicit phrasing in the request (e.g. "approve this PR", "please approve", "LGTM approve it"). A plain review with no approval language behaves read-only as before.

- The command forwards the approval phrasing verbatim to the agent (the prompt no longer strips the user's wording).
- The agent reviews first, then: **clean review** → self-approves via `gh pr review <url> --approve --body "<review summary>"` and ends with `✅ Approved and commented.`; **questionable review** (blocking/critical findings or any `(? )` uncertainty) → does **not** approve and instead emits `⚠️ APPROVAL WITHHELD — needs your confirmation`.
- Subagents can't reliably prompt the human, so the confirmation lives in the command (interactive layer): on the withhold marker it relays the summary, asks the user, and approves on confirmation. The post-confirmation `gh pr review --approve` runs in the primary agent's context, so it's subject to the user's top-level/global permission config (no project `opencode.json` exists).

### Severity-grouped report (`/review-deep`)

The `review-vetter` reduce step still dedupes, clusters across the 3 passes, and verifies each finding against the actual diff. Only the **final grouping** changed: survivors are grouped by **severity** (`# Critical` / `# Medium` / `# Low`) instead of by confidence. The cross-pass agreement count is preserved as a per-finding tag (e.g. `(P1, P2 — verified)`), and the sign-off keys off the Critical section (✅ if empty). The `# Dropped on review` section is retained.

## Examples must stay generic

This is a multi-tenant tool — no real project keys, board IDs, Jira URLs, org names, or user names in committed code. Use `PROJ-123`, `<BOARD-ID>`, `<JIRA_URL>`, `<URL|PAGE-ID>`, etc. in all examples, comments, commands, skills, and docs. The only place real values belong is `~/.jirasik/config` (generated by `setup.sh`, gitignored).

## Gotchas

- Invalid session: re-auth via Firefox, re-run setup
- Run setup.sh from repo root
- `~/.jirasik/config` stores `JIRA_URL`; `~/.jirasik/projects` lists registered project dirs (one per line)
- JQL search: use `scripts/search_issues.sh` — the legacy `/rest/api/3/search` endpoint was removed by Atlassian (CHANGE-2046). The helper hits `/rest/api/3/search/jql`.
- **Scripts are symlinked**: `setup.sh` installs `~/.jirasik/scripts/*` as symlinks back into this repo, so `git pull` here propagates immediately. If you ever see drift (a script behaves like an older revision), check whether the install is actually linked: `ls -la ~/.jirasik/scripts/<name>.sh` — should show `->` pointing back here. If it shows a regular file, re-run `setup.sh` to migrate.

## Assignee resolution (`/user/search`)

The Jira Cloud user-search endpoint is finicky:
- Use `/user/search` (singular). The `/users/search` (plural) returns unfiltered results.
- A query that returns no users on the first try may still match — the index isn't deterministic for partial names. Try the exact email first, then the displayName, then the username portion of the email.
- Two records can share a displayName (the human + their Jira Service Management portal alias). Always filter to `accountType == "atlassian"` and `active != false` before picking.
- Even after filtering, a returned account may still be non-assignable (deactivated for issue assignment but live for read). The `POST /issue` call will fail with `User '<id>' cannot be assigned issues.` — handle this as a hard error and prompt for a different assignee.
- For "current user", **always** use `GET /myself` rather than searching by email — it's authoritative and avoids the duplicate-account problem.
