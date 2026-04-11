# jirasik

Jira integration for [OpenCode](https://opencode.ai) using Firefox session cookies.

## OpenCode Commands

| Command | Description |
|---------|-------------|
| `/jira TICKET-123` | Ticket details + branch name |
| `/move TICKET-123` | Move ticket to new status |
| `/todos` | Your tickets in current sprint |
| `/pr URL` | Review GitHub PR |

## CLI

Run `jirasik` anywhere for interactive menu, or pass args for quick access.

```bash
jirasik              # Interactive menu
jirasik PROG-123     # Fetch ticket directly
jirasik -t -n       # Quick todos (no banner)
jirasik -c PROG-123  # View comments
jirasik -a PROG-123 "Looks good"  # Add comment
jirasik -h          # Show all options
```

## Setup

```bash
git clone https://github.com/YOUR_USERNAME/jirasik.git
cd jirasik
bash setup.sh
```

Setup asks for Jira URL, opens Firefox for login, installs to `~/.jirasik/`.

## How it works

1. Firefox stores Jira session cookies in local SQLite DB
2. Scripts extract session token from cookie DB
3. Call Jira REST API directly with session cookie
4. Commands detect expired sessions, prompt re-authentication

## Roadmap

Potential features:

- [x] **Comments** - Read + post comments on tickets
- [ ] **Assign/reassign** - Change assignee on existing tickets
- [ ] **Edit ticket fields** - Update summary, description, priority, story points
- [ ] **Link tickets** - Create issue links (blocks, is blocked by, relates to)
- [ ] **Log work** - Time tracking against tickets
- [ ] **Search / JQL** - Run arbitrary JQL queries from CLI
- [ ] **Notifications** - View recent activity, mentions, updates on watched tickets
- [ ] **Backlog view** - Browse backlog beyond current sprint

## Requirements

- [OpenCode](https://opencode.ai)
- [Firefox](https://www.mozilla.org/firefox/)
- [bun](https://bun.sh) or Node.js
- [gum](https://github.com/charmbracelet/gum)
- [glow](https://github.com/charmbracelet/glow) (markdown rendering)
- `jq`, `sqlite3`, `curl`
