---
description: List all Jira tickets assigned to you (read-only, safe)
---

Below is the captured sprint todos output. Render it as described.

!`~/.jirasik/scripts/fetch_todos.sh`

If the output above contains `{"error": "no_config"}`, the config file is missing. Tell the user to run `setup.sh` from the jirasik repo.

If the output contains `{"error": "auth_failed"}` or `{"error": "no_token"}`, the session has expired. Re-authentication is interactive and needs a terminal, so do NOT attempt it yourself — tell the user to run `jirasik -n` in their own terminal. That prompts them to either log in to the Firefox window it opens, or paste the `tenant.session.token` cookie from a browser they are already signed in to. Once they confirm, re-run `~/.jirasik/scripts/fetch_todos.sh`.

Otherwise, parse the captured output and re-render it in your reply as a markdown table. Use these conventions:

- Header: `### Todos for <date>` followed by a dim/italic line `_<sprint name>_`.
- Columns: `Ticket | Epic | Title | Pts | Status`.
- The script output has two row groups separated by a horizontal-rule line of `─` characters: the upper group is in-progress / not-started tickets, the lower group is completed (Done) tickets. Render BOTH groups in the same table, in order, but visually distinguish them:
  - For tickets in the upper (active) group, wrap the **Status** value in `**bold**` when it is "Ready for Review", "In Review", "Awaiting...", or any review/wait state (these are the most actionable). Leave other statuses (Not Started, Backlog, In Progress, On Hold) unstyled.
  - For tickets in the lower (Done) group, wrap the **Title** AND **Status** in `~~strikethrough~~` so the row reads as completed/dimmed. Keep the `✓` mark in the Status if present.
- Always wrap **Ticket** keys in `` `code spans` `` (e.g. `` `PROJ-123` ``) so they render in monospace.
- After the table, on its own line, render the summary stats as: `**<N> pts todo** | **<N> pts done** | **<N> pts total**` (matching whatever the script reported, including any `(N unpointed)` suffix).
- Then ask: "Which ticket would you like to work on?"

Do NOT echo the raw captured ANSI/text in your reply. Render ONLY the markdown table + summary + question. If they pick a ticket, run the /jira workflow.

This is read-only. Never modify any ticket from this view.
