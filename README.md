# jirasik

Jira integration for [OpenCode](https://opencode.ai) using Firefox session cookies.

## OpenCode Commands

| Command | Description |
|---------|-------------|
| `/jira TICKET-123` | Ticket details + branch name |
| `/move TICKET-123` | Move ticket to new status |
| `/todos` | Your tickets in current sprint |
| `/confluence URL` | Read a Confluence page |
| `/pr URL` | Quick GitHub PR review — pulls linked Jira ticket context; say "approve" to approve + comment |
| `/pr-full URL` | Thorough GitHub PR review — same Jira context + approval support |
| `/review [RANGE]` | Pre-PR self-review of the current branch |
| `/review-deep [RANGE]` | Deep self-review — 3 passes + vetting, findings grouped by severity |

## CLI

Run `jirasik` anywhere for interactive menu, or pass args for quick access.

```bash
jirasik              # Interactive menu
jirasik PROG-123     # Fetch ticket directly
jirasik -t -n       # Quick todos (no banner)
jirasik -c PROG-123  # View comments
jirasik -a PROG-123 "Looks good"  # Add comment
jirasik -w <URL|PAGE-ID>  # Fetch Confluence page (rendered + scrollable)
jirasik -h          # Show all options

jirasik-update      # Update the checkout + refresh the install (see Updating)
```

## Setup

```bash
git clone https://github.com/YOUR_USERNAME/jirasik.git
cd jirasik
bash setup.sh
```

Setup asks for Jira URL, opens Firefox for login, installs to `~/.jirasik/`.

## Updating

```bash
jirasik-update      # Pull latest, refresh install if anything changed
```

Run it from any directory. It fetches the repo, and only if there are new
commits does it fast-forward pull and re-run `setup.sh --update` (non-interactive
"keep current settings") to relink scripts and reinstall OpenCode commands. It
reports whether anything changed. If the checkout has uncommitted changes or has
diverged from its upstream, it stops and tells you to resolve it manually.

Scripts and the `jirasik`/`jirasik-update` binaries are symlinked into
`~/.jirasik/`, so a plain `git pull` in the checkout already applies code
changes immediately — `jirasik-update` just automates the pull plus the
project-command refresh.

## How it works

1. Firefox stores Jira session cookies in local SQLite DB
2. Scripts extract session token from cookie DB
3. Call Jira REST API directly with session cookie
4. Commands detect expired sessions, prompt re-authentication

## Roadmap

Potential features:

- [x] **Comments** - Read + post comments on tickets
- [x] **Confluence** - Fetch + render Confluence pages
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
- [pandoc](https://pandoc.org) (optional — HTML→markdown for Confluence pages)
- `jq`, `sqlite3`, `curl`
