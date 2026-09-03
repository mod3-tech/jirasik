# Changelog

A rolling, newest-first log of notable user-facing changes to jirasik. Dates are
the date the change landed (`YYYY-MM-DD`). This is a curated summary, not a
one-to-one mirror of git history — routine fixes, typos, and doc tweaks are omitted.

## 2026-09-03

- Re-auth: you can now **paste a session cookie from your own browser** instead of
  logging in to jirasik's dedicated Firefox profile. That profile has no password
  manager or SSO session, so an expired session used to mean retyping credentials
  into a bare browser. The prompt now shows your Jira URL to open anywhere you're
  already signed in — copy `tenant.session.token` from DevTools and paste it.
  A whole `name=value` pair or full cookie string is accepted.
- Re-auth: **retries in a loop** until it succeeds or you hit Ctrl-C, instead of
  giving up after one failed attempt. `r` reopens Firefox; Enter re-checks the
  Firefox profile.
- Re-auth: never prompts without a terminal. Non-interactive callers (agents,
  pipes) now get `{"error":"auth_failed","status":401,...}` and exit 2 rather
  than failing with an opaque message.
- `setup.sh` no longer aborts with "log in and re-run setup" on first-time auth —
  it authenticates in place via the same loop.
- Fixed: the fallback path taken when `lib/firefox.sh` can't be sourced ran
  `pkill -f "[Ff]irefox"`, killing *every* Firefox process including your personal
  browsing session. It's now scoped to jirasik's own profile.
- `~/.jirasik/session_token` is now written with `0600` permissions.

## 2026-06-16

- PR authoring: always fill the work repo's PR template (reproduce its exact
  structure; pass via `--body-file` so GitHub can't skip it); fall back to a
  default body only when no template exists.
- PR authoring: write the **Testing** section for QA — a skilled non-developer.
  UI-only steps, concrete inputs, explicit expected results, shortest happy-path
  first, prerequisites up front; route non-UI verification to a developer.
- Branch & PR names: target ≤50 characters total (including the `TICKET-ID-` prefix).
- `/pr` & `/pr-full`: on approval, remove a configured "needs review" label
  (`PR_REVIEW_LABEL` in `~/.jirasik/config`; empty/unset = skip). Preserved across
  `setup.sh` updates.
- `/todos` & sprint view: order cards by Jira board **Rank** (drag/drop order)
  instead of last-updated time.
- Moving tickets: casual phrasing ("move to done") runs the move directly, with
  **no confirmation prompt**; ticket resolved from context. Fast-forward now
  chains through every intermediate status (e.g. Ready for Review → In Review →
  …) instead of stopping one step short, and never ends on a question.
- Jira comments & descriptions: always use ADF, never Markdown (Jira does not
  render Markdown).

## 2026-06-02

- `jirasik -u` / `--update`: update jirasik from the CLI (pull + non-interactive
  setup refresh).
- `bin/jirasik-update`: one-shot `git fetch` + `--ff-only` pull + `setup.sh --update`,
  runnable from any directory; reports what changed.

## 2026-05-29

- PR review (`/pr`, `/pr-full`): gather linked Jira ticket context before reviewing,
  and read the diff in light of it.
- PR review: self-approve on explicit request, with confirm-when-questionable.
- `/review-deep`: group vetted findings by severity instead of confidence.

## 2026-05-26

- PR review agents read existing PR comments first to avoid duplicating feedback.

## 2026-05-22

- Review agents: added a verification gate and sequential finding numbering.

## 2026-05-18

- Multi-tenant: replaced project-specific references with generic placeholders and
  added a generic-examples rule.
- Skill: documented `jira-api.sh` ad-hoc operations.

## 2026-05-14

- `setup.sh` symlinks scripts into `~/.jirasik/scripts` instead of copying, so
  `git pull` propagates immediately.

## 2026-05-13

- Assignee lookup uses the `/user/search` (singular) endpoint for correct results.

## 2026-05-11

- All `jirasik` CLI invocations in agent docs require the `-n` (no-banner) flag.
- Skills install into `<name>/SKILL.md` subdirectories.

## 2026-05-08

- Added `/review-deep`: deep pre-PR self-review (3 passes + vetter).

## 2026-04-29

- Split `/pr` into quick critical-issue triage and `/pr-full` thorough review.
- Added `/review` for pre-PR self-review of local branches.
- PR review agents gained judgment-calibration rules.

## 2026-04-21

- Added `/confluence` (`-w` / `--wiki`) to fetch Confluence pages.
- Added `jira-api.sh`, a generic authenticated Jira API wrapper, and routed all
  built-in scripts through it.

## 2026-04-17

- Added `search_issues.sh` for the `/search/jql` endpoint.

## 2026-04-13

- `/move` supports multiple tickets and fast-forwards through intermediate statuses.
- `setup.sh` supports multiple registered projects.

## 2026-04-10

- Added comment reading/writing for issues.
- Added the create-ticket command.

## 2026-04-07

- Added the `/pr` command and review agent.
- Added token caching and session auto-validation to auth.

## 2026-04-03

- Reworked authentication (Firefox session-token method) and rebuilt the script set;
  config directory moved to `~/.jirasik`. This is the basis of the current architecture.

## 2025-02-28

- Initial release: setup script, sprint/points/status scripts, and basic Jira
  workflow tooling.
