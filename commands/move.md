---
description: Move a Jira ticket to a new status
---

## Input formats

This command accepts tickets in two ways:

1. **Single ticket key as argument:** `/move ERS-123`
2. **Bulk paste in the user's message:** The user may paste a table/list of tickets (e.g. from `/my-tickets` output). Each line contains a ticket key matching the pattern `[A-Z]+-\d+` along with other columns (epic, summary, points, status). Extract all ticket keys from the pasted content.

## Workflow

### Step 1: Identify tickets

- If `$ARGUMENTS` contains a single ticket key, use that.
- If the user's message contains pasted lines with ticket keys, extract ALL ticket keys (regex: `[A-Z]+-\d+` at the start of each line).
- If no tickets can be identified, remind the user: `/move PROJ-123` or paste a list of tickets.

### Step 2: Fetch status and transitions

Run `~/.jirasik/scripts/transition.sh <TICKET-KEY>` for each ticket. Run them **in parallel** when there are multiple tickets.

**Error handling:**
- `{"error": "no_config"}` → tell the user to run `setup.sh`.
- `{"error": "auth_failed"}` or `{"error": "no_token"}` or "Session expired" → tell the user Firefox was opened for re-authentication — log in and re-run the command.
- "Usage:" → remind the user to provide a ticket key.

### Step 3: Display results

Show a summary table of all tickets with their current status and available transitions.

### Step 4: Ask the user

Ask which transition to apply and to which tickets. The user may say:
- "all to Done" → apply the same transition to every ticket
- "ERS-123 to Done, ERS-456 to In Progress" → different transitions per ticket
- Pick from a list, etc.

### Step 5: Confirm and execute

Show exactly what will happen (ticket key, current status → target status) and ask for confirmation. Once confirmed, run:

```
~/.jirasik/scripts/transition.sh <TICKET-KEY> "<TRANSITION-NAME>"
```

Execute all transitions **in parallel**. Show results in a summary table.

After completion, ask if the user wants to move any of them again.

### Safety rules
- Always show the current status and target transition before executing.
- Always confirm with the user before executing the transition.
