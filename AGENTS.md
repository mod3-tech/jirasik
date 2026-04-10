# AGENTS.md

## Developer commands

```bash
bash setup.sh          # Interactive setup (asks for Jira subdomain, project dir)
./bin/jirasik         # Interactive menu
./bin/jirasik PROG-123  # Fetch ticket directly
./bin/jirasik -t -n   # Quick todos (no banner)
./bin/jirasik -m PROG-123 "In Progress"  # Move ticket
```

## Architecture

- Scripts copied to `~/.jirasik/` on setup
- OpenCode commands installed to `{PROJECT_DIR}/.opencode/commands/`
- Auth: extracts session cookie from Firefox's SQLite cookie DB
- No tests, lint, or build — pure bash/CLI

## Commands reference

| OpenCode | CLI equivalent | Description |
|----------|---------------|-------------|
| `/jira TICKET` | `jirasik TICKET` | Ticket details |
| `/move TICKET` | `jirasik -m TICKET` | Move to status |
| `/todos` | `jirasik -t` | Sprint tickets |
| `/pr URL` | — | GitHub PR review |

## Gotchas

- Invalid session: re-authenticate via Firefox, then re-run setup
- Run setup.sh from repo root (checks for scripts/fetch_ticket.sh)
- `~/.jirasik/config` stores `JIRA_URL` and `PROJECT_DIR`