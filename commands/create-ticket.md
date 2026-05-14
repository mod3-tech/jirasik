---
description: Create a new Jira ticket
---

Gather information from the user in two stages: required fields first, then optional fields in a batch.

### Required fields (ask one at a time)

1. **Project key** - The Jira project key (e.g., `PROG`, `DEV`, `OPS`). If they don't know it, you can suggest checking a similar ticket's key or their Jira project URL.

2. **Title** - A brief summary of the ticket.

3. **Issue type** - The type of issue. First, run:

   ```
   ~/.jirasik/scripts/get_issue_types.sh <PROJECT-KEY>
   ```

   Then show the available types and let the user pick one. Common types: `Task`, `Bug`, `Story`, `Epic`.

4. **Short description** - A brief 1-2 sentence summary of the ticket. Keep it concise.

### Optional fields (ask together in one prompt)

After getting the required fields, present all optional fields at once and let the user answer whichever they want. They can skip any or all.

5. **Details** - Additional context, steps to reproduce, links, or information. For bugs, include steps to reproduce, expected vs actual behavior, links to recordings, and environment info. If the user provides a **file path** instead of inline text, read the file contents and use that as the details.

6. **Priority** - The ticket priority. Run `~/.jirasik/scripts/get_priorities.sh` to show available options. Common values: `Highest`, `High`, `Medium`, `Low`, `Lowest`

7. **Parent ticket** - A parent ticket key (e.g., `PROG-100`). If the user names a parent by title (e.g., "Tech Debt"), use the search helper:

   ```
   ~/.jirasik/scripts/search_issues.sh 'project=<PROJECT-KEY> AND issuetype=Epic AND summary~"<TITLE>"'
   ```

   Output is tab-separated: `<KEY>\t<STATUS>\t<SUMMARY>`. Do NOT hand-roll a curl against `/rest/api/3/search` — that endpoint was removed by Atlassian. `search_issues.sh` and `jira-api.sh` both use the correct `/rest/api/3/search/jql` endpoint; if you need richer JQL output than `search_issues.sh` provides, call `~/.jirasik/scripts/jira-api.sh GET /search/jql --query jql='...'` directly.

8. **Sprint** - Add the ticket to a sprint. Run `~/.jirasik/scripts/get_sprints.sh <PROJECT-KEY>` to show available sprints with IDs.

9. **Story points** - A point estimate (e.g., 1, 2, 3, 5, 8, 13). Not supported by the create script — set via API after creation (see below).

10. **Assignee** - Who to assign the ticket to. Tickets land **unassigned** unless explicitly set (the script does not default to the current user). If the user wants it assigned to themselves, skip `--assignee` during creation and use `GET /myself` accountId in the post-creation assign step — it's authoritative and avoids the email-search lookup landmines noted in AGENTS.md. Pass `--assignee` only when the user named someone else; resolve via `~/.jirasik/scripts/search_users.sh <NAME>` first to verify the right person. If `--assignee` lookup is ambiguous, `create_ticket.sh` errors out (does not silently create unassigned).

### Create the ticket

Run:

```
~/.jirasik/scripts/create_ticket.sh "<PROJECT-KEY>" "<TITLE>" "<ISSUE-TYPE>" [--desc "<SHORT-DESC>"] [--details "<DETAILS>"] [--priority "<PRIORITY>"] [--assignee "<NAME-OR-EMAIL>"] [--parent "<PARENT-KEY>"] [--sprint "<SPRINT-ID>"]
```

Only include the flags for fields the user provided. Omit flags for empty/skipped fields.

Use `--dry-run` to preview the payload without creating the ticket.

**Handling large details content:** If the details text is very long (e.g., read from a file), the shell argument may fail. In that case, write the JSON payload to a file (or stdin) and POST it via `jira-api.sh`:
```
~/.jirasik/scripts/jira-api.sh POST /issue --data-file payload.json
# or: cat payload.json | ~/.jirasik/scripts/jira-api.sh POST /issue --data-file -
```

### After creation

If the ticket was created successfully, show the ticket key and URL.

**Assign the ticket (REQUIRED — do not skip).** Tickets created via the API land unassigned by default. Always perform this step immediately after creation, before offering any other follow-ups:

1. If the user supplied `--assignee` during creation, verify the response shows `fields.assignee` is non-null. If null, the lookup failed silently — fall through to step 2.
2. Otherwise, default to the current user. Get their accountId once:
   ```
   ACCOUNT_ID=$(~/.jirasik/scripts/jira-api.sh GET /myself --raw | jq -r .accountId)
   ```
   Then assign:
   ```
   ~/.jirasik/scripts/jira-api.sh PUT /issue/<TICKET-KEY> --data "{\"fields\":{\"assignee\":{\"accountId\":\"$ACCOUNT_ID\"}}}"
   ```
3. If the user named someone else, resolve via `~/.jirasik/scripts/search_users.sh <NAME>`, confirm the match, then PUT as above with their accountId.

Confirm assignment succeeded by re-reading the ticket or checking the PUT response (204 No Content = success).

**Set story points** (if provided) via the API since the create script doesn't support it:
```
~/.jirasik/scripts/jira-api.sh PUT /issue/<TICKET-KEY> --data '{"fields":{"customfield_10026":<POINTS>}}'
```

Then ask if they'd like to do any of the following — but **only offer actions for fields that were not already set** during creation:
- Reassign to someone else (assignee is now set — only offer if user wants to change it)
- Set priority (only if not already set)
- Add to a sprint (only if not already set)
- Set story points (only if not already set)
- Start working on it (create branch, etc.)

### Error handling

If the output contains `{"error": "no_config"}`, tell the user to run `setup.sh`.

If the output contains "Failed to create ticket", show the error and ask if they want to try again with different details.

### Safety rules
- Creating a ticket is a write operation — always confirm the details with the user before executing.
- Show the planned ticket summary (project, title, short description) before running the create command.