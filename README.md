# opencode-jira-firefox

Jira integration for [OpenCode](https://opencode.ai) using Firefox session cookies. Read your sprint board and ticket details without leaving the terminal.

## How it works

Jira Cloud (Atlassian) doesn't offer simple personal API tokens when SSO/passkey auth is enforced. This project works around that by:

1. You log into Jira once in a dedicated Firefox profile
2. Firefox stores your session cookies in a local SQLite database
3. Bash scripts extract the session token from the cookie DB and call the Jira REST API directly
4. OpenCode custom commands (`/todos`, `/jira`) invoke these scripts and display the results inline

When your session expires, the commands detect it automatically and prompt you to re-authenticate.

## What you get

| Command | Description |
|---------|-------------|
| `/todos` | Lists all Jira tickets assigned to you in the current sprint, with status, epic, story points, and a summary line |
| `/jira TICKET-123` | Fetches a single ticket's details: status, assignee, priority, sprint, epic, description, and a suggested branch name |

## Prerequisites

- [OpenCode](https://opencode.ai)
- [Firefox](https://www.mozilla.org/firefox/) (any recent version)
- [bun](https://bun.sh) or [Node.js](https://nodejs.org) (for `bunx`/`npx`)
- [gum](https://github.com/charmbracelet/gum) (for the interactive CLI menu)
- `jq`, `sqlite3`, `curl` (pre-installed on macOS; install via your package manager on Linux)

## Quick start

```bash
# Install gum (required for interactive menu)
brew install gum  # macOS
# or: apt install gum  # Linux

git clone https://github.com/YOUR_USERNAME/opencode-jira-firefox.git
cd opencode-jira-firefox
bash setup.sh
```

The setup script will:

1. Ask for your Jira Cloud URL (e.g. `https://yourcompany.atlassian.net`)
2. Create `~/.firefox-mcp-jira/` and install the scripts there
3. Copy the `/jira` and `/todos` commands into your project's `.opencode/commands/` directory
4. Print instructions for the one-time Firefox login

### Firefox DevTools MCP

The commands need the [Firefox DevTools MCP](https://www.npmjs.com/package/firefox-devtools-mcp) server for re-authentication flows. Add it to your project's `opencode.json`:

```json
{
  "mcp": {
    "firefox devtools": {
      "type": "local",
      "command": [
        "bunx", "-y",
        "firefox-devtools-mcp@latest",
        "--headless", "--viewport", "1280x720"
      ]
    }
  }
}
```

### First login

Log into Jira once to create session cookies:

```bash
bunx -y firefox-devtools-mcp@latest --viewport 1280x720 \
  --profile-path ~/.firefox-mcp-jira \
  --start-url https://yourcompany.atlassian.net
```

A Firefox window will open. Log in with your credentials, then close it (Ctrl+C). Your session is now persisted in `~/.firefox-mcp-jira/`.

## Usage

### CLI (standalone)

After setup, run `jirasik` from anywhere for an interactive menu:

```bash
jirasik
```

(Setup creates a symlink in `~/bin`. Make sure `~/bin` is in your PATH - add `export PATH="$HOME/bin:$PATH"` to `.zshrc`.)

This opens a TUI with options to:
- Fetch a ticket by key
- View your sprint todos
- Open Jira in browser
- Re-authenticate

### OpenCode commands

```
/todos              # sprint board
/jira PROJ-123      # single ticket by key
/jira https://yourcompany.atlassian.net/browse/PROJ-123   # or by URL
```

### Session expiry

When your Jira session expires, the commands return `{"error": "auth_failed"}`. OpenCode will automatically detect this and prompt you to re-authenticate by launching Firefox with your saved profile. Log in again, close Firefox, and the commands work again.

## File layout

```
~/.firefox-mcp-jira/
  config              # JIRA_URL setting
  jirasik            # CLI wrapper (interactive menu)
  fetch_ticket.sh     # single-ticket fetch script
  fetch_todos.sh      # sprint board fetch script
  cookies.sqlite      # Firefox cookie database (created after first login)
  session_token       # cached token (auto-managed, deleted on auth failure)
  epic_cache.json     # cached epic names (auto-managed)
```

## How the scripts work

Both scripts follow the same pattern:

1. **Read config** -- source `~/.firefox-mcp-jira/config` for `JIRA_URL`
2. **Extract token** -- query Firefox's `cookies.sqlite` for the `tenant.session.token` cookie, cache it in `session_token`
3. **Call Jira REST API** -- `curl` with the session cookie to fetch ticket/sprint data
4. **Format output** -- parse JSON with `jq`, display a formatted table with ANSI colors
5. **Handle errors** -- return structured JSON errors that the OpenCode commands understand

Epic names are cached in `epic_cache.json` to avoid redundant API calls.

## Customization

### Custom fields

The scripts use Jira custom field IDs that are specific to your instance:

- `customfield_10026` -- Story Points
- `customfield_10021` -- Sprint
- `customfield_10014` -- Epic Link

If your Jira instance uses different field IDs, update the `fields=` parameters in the scripts. You can find your field IDs at `https://yourcompany.atlassian.net/rest/api/3/field`.

## Future

GitHub commands (`/pr-create`, `/pr-status`, `/pr-list`) are planned. These will use the `gh` CLI instead of Firefox cookies since GitHub has proper CLI authentication.

## License

MIT
