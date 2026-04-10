---
description: Read a Jira ticket and display its details (read-only, safe)
---

Display the following Jira ticket data as-is. It is already formatted.

!`~/.jirasik/fetch_ticket.sh $ARGUMENTS`

Also display recent comments on this ticket:

!`~/.jirasik/comments.sh $ARGUMENTS`

If the output above contains `{"error": "no_config"}`, the config file is missing. Tell the user to run `setup.sh` from the jirasik repo.

If the output contains `{"error": "auth_failed"}` or `{"error": "no_token"}`, the session has expired. Start Firefox in visible (non-headless) mode with headless=false, profilePath=`~/.jirasik`, startUrl=`__JIRA_URL__`. Tell the user to log in (do NOT fill in credentials). After login, close Firefox and re-run `~/.jirasik/fetch_ticket.sh $ARGUMENTS`.

If the output contains `{"error": "no_argument"}`, remind the user to provide a ticket key or URL: `/jira PROJ-123` or `/jira __JIRA_URL__/browse/PROJ-123`.

Otherwise, display the output as-is and ask the user what they'd like to do next. Typical workflow is:
- Investigate the issue in the codebase
- Create the branch and start working
- Eventually: test, PR, review, status changes through the Jira lifecycle

### Safety rules for all Jira interactions

- **Reading** ticket info: always safe, no confirmation needed.
- **Any write** to Jira (status change, comment, field edit): always show what will change and confirm with the user first. Never auto-execute.
- **Any git operation** (create branch, push, etc.): always show the command and confirm first.
- Branch name pattern is always `<TICKET-ID>-<slugified-title>` with no type prefix.
