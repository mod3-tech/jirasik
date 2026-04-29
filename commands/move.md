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

### Step 5: Preview and execute

Print a brief preview line per ticket showing what will happen, then execute immediately. Format:

```
PROG-123: In Progress → Done
PROG-124: Not Started → Done (auto-chaining)
```

Then run:

```
~/.jirasik/scripts/transition.sh <TICKET-KEY> "<TRANSITION-NAME>"
```

Execute all transitions **in parallel**. Show results in a summary table.

#### When to ask for confirmation

- **Target is "Done" (or close-out intent)** → no confirmation. Print the preview and execute.
- **Ambiguous target or user picked an intermediate status explicitly** → confirm **once** before executing.
- **Already-Done tickets** → skip silently and note in the summary as `already Done (skipped)`. Treat any of these as terminal: `Done`, `Closed`, `Resolved`, `Cancelled`, `Won't Do`, `Won't Fix`. If the user-stated target matches the current status, also skip.

After completion, do not ask follow-up questions unless something failed.

### Step 6: Fast-forward through intermediate statuses

If the target status is not directly available from the current status (e.g. moving to "Done" from "Not Started"), automatically chain through intermediate transitions to reach it:

1. **No confirmation** when the target is Done — the preview line already declares `(auto-chaining)`.
2. **Auto-chain** — repeatedly:
   a. Fetch available transitions for the current status.
   b. Pick the most logical forward transition toward the target (prefer transitions that move the ticket forward: e.g. "In Progress" → "Ready for Review" → "In Review" → "Ready for QA" → "In QA" → "Done").
   c. Execute the transition.
   d. Repeat until the target is reached or no forward transition is available.
3. **No intermediate prompts** — never ask between steps. Never ask "should this go through QA first?" or similar — the user does not use intermediate columns as gates.
4. **Show a summary** at the end listing the full chain (e.g. `Not Started → In Progress → Ready for Review → In Review → Ready for QA → In QA → Done`).
5. **Bail out** if a transition loop is detected or no available transition moves toward the target. Report the current status and remaining options.

### Safety rules
- Always print the preview line(s) before executing, so the user sees what happened.
- Do **not** prompt for confirmation when the target is Done / when the user said "close out" / "close this" / similar close-out intent.
- Do **not** suggest QA, review, or any other intermediate step as a "should we do this first?" question. The intermediate columns exist for corporate workflow only; the user moves straight to Done by design.
