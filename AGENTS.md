# AGENTS.md

## Developer Commands

Run non-interactive scripts from `scripts/` only. `setup.sh` + `./bin/jirasik` require TTY — do not auto-run.

```bash
jirasik PROG-123        # Fetch ticket
jirasik -t              # Sprint todos
jirasik -s              # View sprint
jirasik -m PROG-123 "In Progress"  # Move ticket
jirasik -c PROG-123      # View comments
jirasik -a PROG-123 "text"  # Add comment
jirasik -p              # Sprint points
jirasik -o              # Open Jira in browser
jirasik -n              # No banner (add to any command)
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
| `/jira TICKET` | `jirasik TICKET` | Ticket details |
| `/move TICKET` | `jirasik -m TICKET` | Move to status |
| `/todos` | `jirasik -t` | Sprint tickets |
| — | `jirasik -c TICKET` | View comments |
| — | `jirasik -a TICKET "text"` | Add comment |
| `/pr URL` | — | GitHub PR review |

## Gotchas

- Invalid session: re-auth via Firefox, re-run setup
- Run setup.sh from repo root
- `~/.jirasik/config` stores `JIRA_URL`; `~/.jirasik/projects` lists registered project dirs (one per line)
- JQL search: use `scripts/search_issues.sh` — the legacy `/rest/api/3/search` endpoint was removed by Atlassian (CHANGE-2046). The helper hits `/rest/api/3/search/jql`.
