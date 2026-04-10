---
description: Create a new Jira ticket
---

Ask the user for the following information:

1. **Project key** - The Jira project key (e.g., `PROG`, `DEV`, `OPS`). If they don't know it, you can suggest checking a similar ticket's key or their Jira project URL.

2. **Title** - A brief summary of the ticket.

3. **Issue type** - The type of issue. First, run:

   ```
   ~/.jirasik/get_issue_types.sh <PROJECT-KEY>
   ```

   Then show the available types and let the user pick one. Common types: `Task`, `Bug`, `Story`, `Epic`.

4. **Short description** - A brief 1-2 sentence summary of the ticket. Keep it concise.

5. **Details** (optional) - Additional context, steps to reproduce, links, or information. For bugs, include:
   - Steps to reproduce
   - Expected vs actual behavior
   - Links to recordings (e.g., jam.dev, Loom)
   - Screenshot references
   - Environment info

   Use paragraphs to separate different sections. Example for a bug:
   ```
   Steps to reproduce:
   1. Go to /settings
   2. Click "Save" button
   3. Observe error in console

   Expected: Save succeeds
   Actual: 500 error returned

   See: https://jam.dev/...
   ```

6. **Priority** (optional) - The ticket priority. Run to see available options:

   ```
   ~/.jirasik/get_priorities.sh
   ```

   Common values: `Highest`, `High`, `Medium`, `Low`, `Lowest`

7. **Assignee** (optional) - Who to assign the ticket to. First, search for users:

   ```
   ~/.jirasik/search_users.sh <SEARCH-TERM>
   ```

   Then provide the display name (e.g., `Jane Smith`)

8. **Parent ticket** (optional) - A parent ticket key to make this a subtask/child of another ticket (e.g., `PROG-100`). Useful for breaking down epics or stories into smaller tasks.

9. **Sprint** (optional) - Add the ticket to a sprint. First, list available sprints:

   ```
   ~/.jirasik/get_sprints.sh <PROJECT-KEY>
   ```

   This shows active and future sprints with their IDs. Use the sprint ID (number) when creating the ticket. If the project uses kanban, no sprints will be shown.

Once you have these, run:

```
~/.jirasik/create_ticket.sh "<PROJECT-KEY>" "<TITLE>" "<ISSUE-TYPE>" [--desc "<SHORT-DESC>"] [--details "<DETAILS>"] [--priority "<PRIORITY>"] [--assignee "<ASSIGNEE>"] [--parent "<PARENT-KEY>"] [--sprint "<SPRINT-ID>"]
```

Only include the flags for fields the user provided. Omit flags for empty/skipped fields.

Use `--dry-run` to preview the payload without creating the ticket.

Display the result. If the ticket was created successfully, show the ticket key and URL, and ask if they'd like to:
- Assign it to someone
- Set priority
- Add to a sprint
- Start working on it (create branch, etc.)

### Error handling

If the output contains `{"error": "no_config"}`, tell the user to run `setup.sh`.

If the output contains "Failed to create ticket", show the error and ask if they want to try again with different details.

### Safety rules
- Creating a ticket is a write operation — always confirm the details with the user before executing.
- Show the planned ticket summary (project, title, short description) before running the create command.