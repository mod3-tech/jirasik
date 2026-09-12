---
description: Deep pre-PR self-review. One adversarial pass that falsifies the change against the schema and spec, plus mandatory mutation-testing of new tests. Replaces the old 3-parallel-passes design.
---

Run a deep self-review of the current branch. Optional `$1`: a submodule path, a git range (e.g. `main...HEAD`), or a base branch name.

Goal: reproduce a cold reviewer. One adversarial pass, no framing leakage, schema facts checked, every new test proven to fail when its bug is reintroduced.

## Steps

1. **Capture the reviewed HEAD.** Record `git rev-parse HEAD`; this is the SHA the review covers. A "ready to merge" claim holds only while HEAD equals it; if HEAD moves, re-run the gate (step 7).

2. **Build the reviewer input mechanically. Strip author framing.** Facts, not narration:
   - `git diff <base/range>` (resolve base from `$1`, else auto-detect the merge base).
   - The full text of every schema/model/migration file the diff touches, so nullability, NULL-sort, indexes, and tenant columns are checked against the real schema.
   - The spec/ticket/PR-body claims as a list of REQUIREMENTS to falsify.

   Do NOT pass commit messages or code comments as authority. Strip any sentence asserting the code is "correct", "already handled", "matches", or "verified". The reviewer derives correctness; it never inherits it.

3. **Spawn one adversarial `branch-review` pass.** A single `Task` call. The pass has two mandatory axes:
   - **Standards axis:** walk the repo's `CLAUDE.md`/`AGENTS.md` conventions against the diff.
   - **Spec axis:** treat every claim in the ticket/PR body/spec as a requirement and try to FALSIFY it against the diff and the schema. For any "X is now handled" claim, trace every sibling code path that reaches the same sink (e.g. every writer of the same field, every query ordering/filtering the same column), not just the path the change named.

   The pass MUST perform a schema-fact check for any data-access change: for every column used in `ORDER BY`/`WHERE`, confirm nullability, NULL sort order handling, soft-delete exclusion, and a tenant filter on every joined table.

4. **Mutation-test every new or changed test.** Not optional, not delegated. For each test the diff adds or changes, reintroduce the bug it guards (flip the operator, drop the filter, remove the NULLS clause) and confirm the test FAILS. A test that still passes guards nothing: report it and treat the code as untested. Restore after each mutation. Script the loop (edit, run the one test, assert red, revert) rather than eyeballing.

5. **Vetting pass.** One `Task` call to the `review-vetter` subagent with the adversarial pass's findings plus your mutation-test results. It verifies each finding against the code, discards false alarms, and tiers survivors (Critical / Medium / Low). Output its response verbatim.

6. **Triage gate. The review's job is to FIND, mine is to SIZE and DECIDE.** Do NOT start editing. Re-tier by *impact*, not correctness; almost every surviving finding is correct, that is the trap:
   - **Blocking** = merge breaks a build/deploy/migration, loses data, or opens a security hole. Nothing else, however confidently phrased (tone never sets severity).
   - **Trigger check:** a correct finding on a path nothing reaches today (dead/stubbed) is capped at Low.
   - **Convention findings are challengeable:** cite the doc line and say whether it fits this case. "The doc is wrong here / needs an exception" is a valid resolution.

   Then STOP and present ONE line: "N blocking, M real-but-low, K convention." Fix blocking automatically. For the rest, touch no code until the user picks (a) fix all, (b) blocking only, (c) choose. No answer means blocking only; ticket the real-but-low, drop pure nitpicks. Do not auto-fix past round 2; if a later round is all Low/convention, ship.

7. **Re-gate rule.** If any finding is fixed (HEAD changes), the review is stale. Re-run against the new HEAD before calling the branch ready, and state the reviewed SHA in the output so staleness is checkable.

## Notes

- Expensive (adversarial pass + mutation testing + vetter). Use `/review` for routine self-checks; reach for this when the change is high-stakes, touches data access, or `/review` keeps surprising you.
- Mutation testing is the highest-signal step for logic/query/money/security paths. If time is tight, cut breadth before cutting it.
- To review a GitHub PR instead of a local branch, use `/pr` (quick) or `/pr-full` (thorough). This command is local-branch only.
