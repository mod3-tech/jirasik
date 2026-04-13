---
description: Move a Jira ticket to a new status
---

Display the following ticket status and available transitions:

!`~/.jirasik/scripts/transition.sh $ARGUMENTS`

If the output contains `{"error": "no_config"}`, tell the user to run `setup.sh`.

If the output contains `{"error": "auth_failed"}` or `{"error": "no_token"}` or mentions "Session expired", the session has expired. Tell the user Firefox was opened for re-authentication — log in and re-run the command.

If the output contains "Usage:", remind the user to provide a ticket key: `/move PROJ-123`.

Otherwise, show the ticket's current status and the available transitions. Ask the user which transition they want. Once they pick one, run:

```
~/.jirasik/scripts/transition.sh <TICKET-KEY> "<TRANSITION-NAME>"
```

Use the exact transition name from the list. After the move succeeds, show the result and ask if they want to move it again (run `transition.sh <TICKET-KEY>` to get the new available transitions).

### Safety rules
- Always show the current status and target transition before executing.
- Always confirm with the user before executing the transition.
