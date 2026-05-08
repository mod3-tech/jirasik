---
description: Deep pre-PR self-review. Runs 3 independent reviews in parallel and a vetting pass to dedup, verify, and rank findings by confidence.
---

Run a deep self-review of the current branch. Optional `$1`: a submodule path, a git range (e.g. `main...HEAD`), or a base branch name — passed through to each review pass.

Strategy: 3 independent review passes (map) → 1 vetting pass (reduce). The map passes find candidate issues with run-to-run variance; the reduce pass dedupes them, verifies each one against the actual diff, and tiers them by agreement count to suppress false alarms.

## Steps

1. **Spawn 3 independent review passes in parallel.** In a single message, make three `Task` tool calls to the `branch-review` subagent. Pass `$1` (if provided) verbatim to each. Each pass runs in its own context — they must not see each other's output.

   The exact prompt for each Task call: `Review the current branch. Optional arg: $1 (a submodule path, a git range, or a base branch name).` (omit "Optional arg: …" if `$1` is empty).

   Wait for all 3 to return.

2. **Collect findings.** From each pass's final message, extract every individual finding (each bullet/numbered item is one finding). Preserve `file:line` references and the original wording. Tag each finding with which pass produced it (P1, P2, P3). Also record each pass's overall sign-off (✅/❌).

   If a pass returned an empty result or only the sign-off, note that and continue with the others. If all three returned empty, output a one-line approval and stop — no vetting needed.

3. **Vetting pass.** Make one `Task` tool call to the `review-vetter` subagent. Pass it the collected findings as a single structured input. Format:

   ```
   Branch: <name from any pass, or "unknown">
   Base/range used: <if any pass mentioned it; else "auto-detected">
   $1 arg (if any): <verbatim or "none">

   Findings from Pass 1:
   - [exact text of finding 1]
   - [exact text of finding 2]
   ...
   Pass 1 sign-off: ✅ | ❌

   Findings from Pass 2:
   ...

   Findings from Pass 3:
   ...
   ```

   The vetter will dedup, verify each finding against the actual code, and return a tiered final review.

4. **Output the vetter's response verbatim** as your final message. Do not add commentary, do not re-summarize, do not append a sign-off of your own — the vetter handles all of that.

## Notes

- This command is expensive (4 subagent runs, 3 in parallel + 1 sequential). Use `/review` for routine self-checks; reach for `/review-deep` when the change is high-stakes or when `/review` keeps surprising you with issues you missed.
- If the user wants to review a GitHub PR rather than a local branch, point them at `/pr` (quick) or `/pr-full` (thorough). This command is local-branch only.
