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

Show exactly what will happen (ticket key, current status → target status) and ask for confirmation **once**. Once confirmed, run:

```
~/.jirasik/scripts/transition.sh <TICKET-KEY> "<TRANSITION-NAME>"
```

Execute all transitions **in parallel**. Show results in a summary table.

After completion, ask if the user wants to move any of them again.

### Step 6: Fast-forward through intermediate statuses

If the user's target status is not directly available from the current status (e.g. asking to move to "Done" from "Not Started"), automatically chain through intermediate transitions to reach it:

1. **Confirm once** — show the starting status, the target status, and explain that intermediate transitions will be applied automatically. Ask for a single confirmation.
2. **Auto-chain** — after confirmation, repeatedly:
   a. Fetch available transitions for the current status.
   b. Pick the most logical forward transition toward the target (prefer transitions that move the ticket forward in the workflow: e.g. "In Progress" → "Ready for Review" → "In Review" → "Ready for QA" → "In QA" → "Done").
   c. Execute the transition.
   d. Repeat until the target status is reached or no forward transition is available.
3. **No intermediate confirmations** — do not ask for confirmation between each step.
4. **Show a summary** at the end listing all transitions that were executed (e.g. `Not Started → In Progress → Ready for Review → In Review → Ready for QA → In QA → Done`).
5. **Bail out** if a transition loop is detected (returning to an already-visited status) or if no available transition moves toward the target. Inform the user of the current status and remaining available transitions.

### Safety rules
- Always show the current status and target transition before executing.
- Confirm with the user **once** before executing. Do not re-confirm for each intermediate transition when fast-forwarding.
