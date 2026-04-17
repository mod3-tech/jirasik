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

   Output is tab-separated: `<KEY>\t<STATUS>\t<SUMMARY>`. Do NOT hand-roll a curl against `/rest/api/3/search` — that endpoint was removed by Atlassian. The helper uses the correct `/rest/api/3/search/jql` endpoint.

8. **Sprint** - Add the ticket to a sprint. Run `~/.jirasik/scripts/get_sprints.sh <PROJECT-KEY>` to show available sprints with IDs.

9. **Story points** - A point estimate (e.g., 1, 2, 3, 5, 8, 13). Not supported by the create script — set via API after creation (see below).

### Create the ticket

Run:

```
~/.jirasik/scripts/create_ticket.sh "<PROJECT-KEY>" "<TITLE>" "<ISSUE-TYPE>" [--desc "<SHORT-DESC>"] [--details "<DETAILS>"] [--priority "<PRIORITY>"] [--parent "<PARENT-KEY>"] [--sprint "<SPRINT-ID>"]
```

Only include the flags for fields the user provided. Omit flags for empty/skipped fields.

Use `--dry-run` to preview the payload without creating the ticket.

**Handling large details content:** If the details text is very long (e.g., read from a file), the shell argument may fail. In that case, build the JSON payload and call the Jira API directly instead of using the create script:
```
curl -sL -b "tenant.session.token=$TOKEN" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$JIRA/rest/api/3/issue"
```

### After creation

If the ticket was created successfully, show the ticket key and URL.

**Set story points** (if provided) via the API since the create script doesn't support it:
```
curl -sL -b "tenant.session.token=$TOKEN" -X PUT -H "Content-Type: application/json" \
  -d '{"fields": {"customfield_10026": <POINTS>}}' "$JIRA/rest/api/3/issue/<TICKET-KEY>"
```

Then ask if they'd like to do any of the following — but **only offer actions for fields that were not already set** during creation:
- Assign it to someone (always offer — assignee is not set during creation)
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