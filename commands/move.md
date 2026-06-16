---
description: Move a Jira ticket to a new status
---

## Input formats

This command accepts tickets in two ways:

1. **Single ticket key as argument:** `/move PROJ-123`
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

### Step 4: Determine the target transition

- **If the user already stated a target** ("move to done", "all to QA", "PROJ-123 to Done, PROJ-456 to In Progress") → use it. Treat the user's word as *intent* and map it to the real transition name for each ticket's workflow (names are project-specific; use the names the API returns). Do **not** ask which transition.
- **Only if no target was given** (e.g. bare `/move PROJ-123`) → ask which transition to apply, and to which tickets.

### Step 5: Execute

**Do not ask for confirmation.** Once the target transition is known, run it directly:

```
~/.jirasik/scripts/transition.sh <TICKET-KEY> "<TRANSITION-NAME>"
```

Execute all transitions **in parallel**. Show results in a summary table.

After completion, ask if the user wants to move any of them again.

### Step 6: Fast-forward through intermediate statuses

If the user's target status is not directly available from the current status (e.g. asking to move to "Done" from "Not Started"), automatically chain through intermediate transitions to reach it:

1. **No confirmation** — proceed directly toward the target status, applying intermediate transitions automatically.
2. **Auto-chain — keep going until you literally cannot move forward.** Loop:
   a. Fetch available transitions for the current status (`transition.sh <KEY>` with no transition name lists them).
   b. **If the target transition is available now, take it and stop** — you're done.
   c. Otherwise pick the most forward transition toward the target and execute it. The target is almost never reachable in one hop — workflows gate "Done" behind review/QA stages (e.g. `In Progress → Ready for Review → In Review → ... → Done`). A transition counts as "forward" if it advances along that lifecycle toward the target, even when its name looks nothing like the target. Use the API's returned names as the source of truth; prefer review/QA/approval/resolve/close-type steps; avoid only clearly backward or sideways ones (Reopen, Not Started, In Progress when you're past it, On Hold, Blocked, Not Needed/Descoped).
   d. Repeat from (a). **Do not stop just because no transition is literally named like the target** — keep taking forward steps. Only stop when the target is reached (b) or you genuinely hit the dead-end condition in 5.
3. **No confirmations, no questions** — never ask for confirmation, and never end on a question or an offer of next steps ("want me to push it one more step?", "leave it here?"). Just keep moving until you reach the target or truly cannot.
4. **Show a summary** at the end listing all transitions that were executed, joined by arrows (e.g. `<status A> → <status B> → <status C>`).
5. **Dead-end (only two cases):** stop and report — as a flat statement, never a question — when either (a) a loop is detected (the only remaining forward transitions return to an already-visited status), or (b) *every* available transition is backward/sideways (none advances toward the target at all). Reaching a state whose forward step simply isn't yet the target is **not** a dead-end — keep going. When you do stop, state the final status reached and the remaining available transitions, and note that further progress likely requires an external gate (e.g. PR approval, QA sign-off). Do not offer choices.

### Safety rules
- **Never prompt for confirmation on a move** — execute directly.
- The only interruptions allowed: (1) ask *which ticket* when zero or multiple keys are in context, or (2) report a failure when the target can't be reached.
- After executing, show what happened (current status → target, or the full transition chain).
