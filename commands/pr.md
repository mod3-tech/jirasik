---
description: Quick critical-issue review of a PR given a GitHub PR URL.
agent: pr-review
---

Review the PR at `$1`.

If my request includes an explicit instruction to approve the PR (e.g. "approve this PR", "please approve", "LGTM approve it"), pass that approval instruction through to the `pr-review` agent verbatim along with the URL — do not strip it. A plain review request with no approval language is just a review.

When the agent's result indicates it **withheld approval pending confirmation** (questionable review — it returns a `⚠️ APPROVAL WITHHELD` marker), relay its summary to me and ask me to confirm the approval. If I confirm, run the approval yourself: `gh pr review <url> --approve --body "<the agent's review summary>"`. If I decline, do nothing further. When the agent already approved (clean review), just relay its result — no confirmation needed.
