---
name: jirasik
description: Manage Jira tickets, sprints, comments, and fetch Confluence pages via the jirasik CLI. Always invoke with -n / --no-banner.
allowed-tools: Bash(jirasik:*)
---

# Jira & Confluence Management with jirasik

Use this skill proactively whenever the user mentions a Jira ticket ID (e.g., ERS-123), asks about sprint status, or references Confluence pages.

## CRITICAL: Always pass `-n` (no-banner)

Every `jirasik` CLI invocation MUST include `-n` / `--no-banner`. The ASCII banner wastes tokens and clutters output. No exceptions.

Note: the underlying scripts at `~/.jirasik/scripts/*.sh` do not print a banner — `-n` is only relevant to the `jirasik` wrapper in `bin/`.

## Commands

```bash
# Fetch a ticket's details
jirasik -n ERS-123

# View current sprint board
jirasik -n --sprint

# View sprint todos
jirasik -n --todos

# Sprint points summary
jirasik -n --points

# Move a ticket (interactive)
jirasik -n --move ERS-123

# Move a ticket to a specific status
jirasik -n --move ERS-123 "In Progress"

# View comments on a ticket
jirasik -n --comments ERS-123

# Add a comment to a ticket
jirasik -n --add-comment ERS-123 "Fixed in latest commit"

# Fetch a Confluence wiki page by URL or page ID
jirasik -n --wiki https://fullsteam.atlassian.net/wiki/x/FQDeow
jirasik -n --wiki 12345

# Open Jira board in browser
jirasik -n --open
```

## Options

- `-n, --no-banner` — Suppress the ASCII banner. REQUIRED on every call.

## Proactive Usage

All examples include `-n` — never omit it.

- When the user mentions a ticket ID like ERS-123, fetch it automatically with `jirasik -n ERS-123`.
- When the user asks about sprint status, use `jirasik -n --sprint` or `jirasik -n --todos`.
- When the user references a Confluence page URL, fetch it with `jirasik -n --wiki <URL>`.
- When starting work on a ticket, move it to "In Progress" with `jirasik -n --move ERS-123 "In Progress"`.
- When work is complete, add a summary comment with `jirasik -n --add-comment ERS-123 "..."`.

## Examples

```bash
# Quick check on a ticket before starting work
jirasik -n ERS-456

# Move ticket and add comment in sequence
jirasik -n --move ERS-456 "In Progress" && jirasik -n --add-comment ERS-456 "Starting work"

# Check sprint
jirasik -n --todos
```
