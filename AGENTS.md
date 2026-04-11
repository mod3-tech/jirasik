# AGENTS.md

## Developer commands

Only run non-interactive scripts from the `scripts/` directory. The `setup.sh` and `./bin/jirasik` scripts are interactive and require a TTY — do not run them automatically.

```bash
# Non-interactive scripts (safe to run):
./scripts/fetch_ticket.sh PROG-123
./scripts/list_tickets.sh
./scripts/move_ticket.sh PROG-123 "In Progress"
# etc — see scripts/ directory
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
| — | `jirasik -c TICKET` | View comments |
| — | `jirasik -a TICKET "text"` | Add comment |
| `/pr URL` | — | GitHub PR review |

## Gotchas

- Invalid session: user must re-authenticate via Firefox, then re-run setup manually
- Run setup.sh from repo root (checks for scripts/fetch_ticket.sh)
- `~/.jirasik/config` stores `JIRA_URL` and `PROJECT_DIR`