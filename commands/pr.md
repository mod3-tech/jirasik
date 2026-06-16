---
description: Quick critical-issue review of a PR given a GitHub PR URL.
agent: pr-review
---

Review the PR at `$1`.

The configured "needs review" label (empty = none configured): !`. ~/.jirasik/config 2>/dev/null; printf '%s' "${PR_REVIEW_LABEL:-}"`

If my request includes an explicit instruction to approve the PR (e.g. "approve this PR", "please approve", "LGTM approve it"), pass that approval instruction through to the `pr-review` agent verbatim along with the URL — do not strip it. Also pass the configured review label above to the agent so it can remove it on approval. A plain review request with no approval language is just a review.

When the agent's result indicates it **withheld approval pending confirmation** (questionable review — it returns a `⚠️ APPROVAL WITHHELD` marker), relay its summary to me and ask me to confirm the approval. If I confirm, run the approval yourself: `gh pr review <url> --approve --body "<the agent's review summary>"`, then — if a review label is configured above — best-effort remove it: `gh pr edit <url> --remove-label "<label>"` (note any failure, but the approval stands). If I decline, do nothing further. When the agent already approved (clean review), just relay its result — no confirmation needed.
