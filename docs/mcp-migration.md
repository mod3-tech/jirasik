# jirasik MCP migration plan

Goal: replace the OpenCode `commands/*.md` wrappers with a single MCP server, so new Jira functionality is added in one place and works across any MCP client. The `jirasik` CLI stays as the primary human interface; the MCP server reuses the existing bash scripts underneath.

Two phases. Phase 1 de-risks the design by keeping the bash scripts as the implementation. Phase 2 is optional and only happens if phase 1 proves the value.

Runtime: Bun + TypeScript, using `@modelcontextprotocol/sdk`.

## Phase 1 — MCP server that shells out to existing scripts

1. Scaffold `mcp/` directory with `package.json`, `tsconfig.json`, `.gitignore` for `node_modules/`, and install `@modelcontextprotocol/sdk` and `zod` via `bun install`. Commit `bun.lock` (text lockfile).

2. Write `mcp/src/server.ts` that boots an MCP stdio server, registers tools (populated in later steps), and exits cleanly on stdin close. No tools yet — just a working handshake.

3. Add `mcp/src/lib/run-script.ts` helper that wraps `Bun.spawn` to execute a script in `~/.jirasik/scripts/`, captures stdout and stderr, and parses the JSON error shapes defined in `AGENTS.md` (`no_config`, `auth_failed`, `not_found`, `http_client`, `http_server`, `removed_endpoint`, `bad_usage`). Returns a discriminated union: `{ok: true, stdout}` or `{ok: false, error: <shape>}`.

4. Add `mcp/src/lib/errors.ts` that converts a parsed error shape into the appropriate MCP error response, with a human-readable message for each case (e.g. `auth_failed` → "Jira session expired, run `jirasik` once to re-authenticate").

5. Register the first tool: `jira_get_ticket`. Input schema: `{key: string}`. Shells out to `fetch_ticket.sh`. Returns the formatted text output. This is the smallest end-to-end slice and validates the whole pipeline.

6. Register read-only tools: `jira_get_todos` (→ `fetch_todos.sh`), `jira_get_sprint` (→ `sprint-view.sh`), `jira_get_comments` (→ `comments.sh`), `jira_get_points` (→ `points.sh`), `confluence_get_page` (→ `fetch_confluence.sh`). Mark all with `readOnlyHint: true`.

7. Register write tools: `jira_transition` (→ `transition.sh`), `jira_add_comment` (→ `add_comment.sh`), `jira_create_ticket` (→ `create_ticket.sh`). Mark with `destructiveHint: true` where appropriate (transitions and comment creation are not destructive; ticket creation is borderline — annotate honestly).

8. Register the generic escape hatch: `jira_api`. Input schema mirrors `jira-api.sh` flags (`method`, `path`, `query?`, `data?`, `api?: "v3" | "agile" | "wiki"`, `raw?: boolean`). This preserves the "ad-hoc API call" capability currently documented in `AGENTS.md`.

9. Update `setup.sh` with an "Install MCP server" menu option that runs `bun install` in `mcp/`, then writes the OpenCode MCP config at `~/.config/opencode/mcp.json` (or the correct path — verify from OpenCode docs) pointing at `bun run <repo>/mcp/src/server.ts`. Include an uninstall path.

10. Add `mcp/README.md` documenting: what the server exposes, how to install it for OpenCode, how to install it for other MCP clients (Claude Desktop, Cursor), and how the auth model works (re-auth still happens via `jirasik` CLI, MCP surfaces the error).

11. Delete the now-redundant command files: `commands/jira.md`, `commands/todos.md`, `commands/move.md`, `commands/create-ticket.md`, `commands/confluence.md`. Keep `commands/pr.md` and `agents/pr-review.md` — they are unrelated subagent workflows.

12. Update `AGENTS.md`: remove the per-command table, replace with a short "Jira capabilities are exposed as MCP tools, see `mcp/README.md`" section. Keep the `jira-api.sh` ad-hoc reference and error-shape table — both are still relevant (they now describe the underlying transport the MCP server wraps).

13. Update root `README.md` install instructions so new users see both paths: "install the CLI" and "install the MCP server".

14. Dogfood for one week. Use the MCP tools for daily Jira work. Note any friction: missing tools, awkward schemas, outputs that don't read well to an agent vs. a human.

## Phase 2 — Optional: port Jira logic into TypeScript

Only start this if phase 1 is in daily use and the "two languages" tax is actually biting. If phase 1 is good enough, stop here.

15. Port `scripts/jira-api.sh` into `mcp/src/lib/jira-api.ts`: native `fetch`, typed request/response, same error taxonomy. Keep the bash version working in parallel — both call the same Jira REST API, so they can coexist.

16. Port the read-only scripts (`fetch_ticket`, `fetch_todos`, `sprint-view`, `comments`, `points`) into TypeScript modules that call the new `jira-api.ts`. Switch the corresponding MCP tools to use the native modules. Delete the bash scripts once the MCP tools pass manual checks.

17. Port the write scripts (`transition`, `add_comment`, `create_ticket`) the same way.

18. Port `scripts/fetch_confluence.sh` including the short-link redirect chasing. This one has the most bash-specific edge cases; budget extra time.

19. Decide the auth story. Two options: (a) keep `scripts/auth.sh` and `scripts/lib/firefox.sh` as a separate "auth helper" invoked by the CLI only, with the MCP server reading a token file it produces; (b) port the Firefox SQLite cookie extraction into TypeScript using `bun:sqlite`. Option (a) is simpler and keeps the Firefox profile logic battle-tested.

20. Rewrite `bin/jirasik` as a thin TypeScript CLI (`mcp/src/cli.ts`) that imports the same library the MCP server uses. Distribute via `bun build --compile` as a single binary, or keep `bun run` for development.

21. Migrate the bats tests: `tests/adf.bats` and `tests/jira-api.bats` become Bun test files (`bun test`) covering the ported modules. Only do this as each script is ported — no big-bang rewrite.

22. Update `setup.sh` to install the compiled binary and MCP server, removing the script-copy-to-`~/.jirasik/scripts/` logic and the `~/.jirasik/projects` multi-project plumbing (MCP is installed once per client, not per project directory).
