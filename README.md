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

Run `jirasik` from anywhere for an interactive menu to fetch tickets, view todos, or open Jira in browser.

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

## Requirements

- [OpenCode](https://opencode.ai)
- [Firefox](https://www.mozilla.org/firefox/)
- [bun](https://bun.sh) or Node.js
- [gum](https://github.com/charmbracelet/gum)
- `jq`, `sqlite3`, `curl`