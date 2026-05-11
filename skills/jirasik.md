---
name: jirasik
description: Manage Jira tickets, sprints, comments, and fetch Confluence pages via the jirasik CLI.
allowed-tools: Bash(jirasik:*)
---

# Jira & Confluence Management with jirasik

Use this skill proactively whenever the user mentions a Jira ticket ID (e.g., ERS-123), asks about sprint status, or references Confluence pages.

## Commands

```bash
# Fetch a ticket's details
jirasik ERS-123

# View current sprint board
jirasik --sprint

# View sprint todos
jirasik --todos

# Sprint points summary
jirasik --points

# Move a ticket (interactive)
jirasik --move ERS-123

# Move a ticket to a specific status
jirasik --move ERS-123 "In Progress"

# View comments on a ticket
jirasik --comments ERS-123

# Add a comment to a ticket
jirasik --add-comment ERS-123 "Fixed in latest commit"

# Fetch a Confluence wiki page by URL or page ID
jirasik --wiki https://fullsteam.atlassian.net/wiki/x/FQDeow
jirasik --wiki 12345

# Open Jira board in browser
jirasik --open
```

## Options

- `-n, --no-banner` — Suppress the ASCII banner for cleaner output

## Proactive Usage

- When the user mentions a ticket ID like ERS-123, fetch it automatically with `jirasik ERS-123`.
- When the user asks about sprint status, use `jirasik --sprint` or `jirasik --todos`.
- When the user references a Confluence page URL, fetch it with `jirasik --wiki <URL>`.
- When starting work on a ticket, move it to "In Progress" with `jirasik --move ERS-123 "In Progress"`.
- When work is complete, add a summary comment with `jirasik --add-comment ERS-123 "..."`.

## Examples

```bash
# Quick check on a ticket before starting work
jirasik ERS-456 -n

# Move ticket and add comment in sequence
jirasik --move ERS-456 "In Progress" && jirasik --add-comment ERS-456 "Starting work"

# Check sprint without banner noise
jirasik --todos -n
```
