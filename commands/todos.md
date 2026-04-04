---
description: List all Jira tickets assigned to you (read-only, safe)
---

Display the following Jira sprint data as-is. It is already formatted.

!`~/.firefox-mcp-jira/fetch_todos.sh`

If the output above contains `{"error": "no_config"}`, the config file is missing. Tell the user to run `setup.sh` from the opencode-jira-firefox repo, or manually create `~/.firefox-mcp-jira/config` with `JIRA_URL="https://yourcompany.atlassian.net"`.

If the output contains `{"error": "auth_failed"}` or `{"error": "no_token"}`, the session has expired. Start Firefox in visible (non-headless) mode with headless=false, profilePath=`~/.firefox-mcp-jira`, startUrl=`__JIRA_URL__`. Tell the user to log in (do NOT fill in credentials). After login, close Firefox and re-run `~/.firefox-mcp-jira/fetch_todos.sh`.

Otherwise, display the output as-is and ask the user which ticket they'd like to work on. If they pick one, run the /jira workflow.

This is read-only. Never modify any ticket from this view.
