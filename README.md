# jirasik

Jira integration for [OpenCode](https://opencode.ai) using Firefox session cookies.

## OpenCode Commands

| Command | Description |
|---------|-------------|
| `/jira TICKET-123` | Single ticket details with branch name |
| `/move TICKET-123` | Move a ticket to a new status |
| `/todos` | Your tickets in the current sprint |
| `/pr URL` | Review a GitHub PR |

## CLI

Run `jirasik` from anywhere for an interactive menu, or pass args for quick access.

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

The setup script asks for your Jira URL, opens Firefox for you to log in, and installs everything to `~/.jirasik/`.

## How it works

1. Firefox stores your Jira session cookies in a local SQLite database
2. Scripts extract the session token from the cookie DB
3. Call Jira REST API directly with the session cookie
4. Commands detect expired sessions and prompt re-authentication

## Roadmap

Potential features to add:

- [x] **Comments** - Read and post comments on tickets
- [ ] **Assign/reassign** - Change assignee on existing tickets
- [ ] **Edit ticket fields** - Update summary, description, priority, story points
- [ ] **Link tickets** - Create issue links (blocks, is blocked by, relates to)
- [ ] **Log work** - Time tracking against tickets
- [ ] **Search / JQL** - Run arbitrary JQL queries from the CLI
- [ ] **Notifications** - View recent activity, mentions, and updates on watched tickets
- [ ] **Backlog view** - Browse the backlog beyond the current sprint

## Requirements

- [OpenCode](https://opencode.ai)
- [Firefox](https://www.mozilla.org/firefox/)
- [bun](https://bun.sh) or Node.js
- [gum](https://github.com/charmbracelet/gum)
- [glow](https://github.com/charmbracelet/glow) (for markdown rendering)
- `jq`, `sqlite3`, `curl`