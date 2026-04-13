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
- OpenCode commands → `{PROJECT_DIR}/commands/`
- Auth: Firefox SQLite cookie DB
- Tests: `./tests/bats/bin/bats tests/`
- Pure bash/CLI — no lint, no build

## Testing

After modifying `scripts/lib/adf.sh`, run tests:

```bash
./tests/bats/bin/bats tests/adf.bats
```

All tests pass before committing `adf.sh`.

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
- `~/.jirasik/config` stores `JIRA_URL` + `PROJECT_DIR`
