#!/bin/bash
# Project .opencode/ install helpers shared by setup.sh and bin/jirasik.
#
# Both take the repo root as the first arg so the caller owns repo-root
# resolution (setup.sh uses $SCRIPT_DIR; bin/jirasik follows its own symlink).

# Install commands/agents/skills from <repo> into <project>/.opencode/.
# __JIRA_URL__ in command files is substituted with <jira_url>.
_jirasik_install_commands_to_project() {
  local repo="$1"
  local project_dir="$2"
  local jira_url="${3:-}"
  local commands_dir="${project_dir%/}/.opencode/commands"
  local agents_dir="${project_dir%/}/.opencode/agents"
  local skills_dir="${project_dir%/}/.opencode/skills"
  mkdir -p "$commands_dir" "$agents_dir" "$skills_dir"

  # Commands: substitute __JIRA_URL__ if present, else plain copy.
  for src in "$repo"/commands/*.md; do
    [[ -f "$src" ]] || continue
    local name; name=$(basename "$src")
    if grep -q '__JIRA_URL__' "$src"; then
      sed "s|__JIRA_URL__|$jira_url|g" "$src" > "$commands_dir/$name"
    else
      cp "$src" "$commands_dir/$name"
    fi
  done

  # Agents: plain copy (no substitution today; if needed later, mirror the
  # __JIRA_URL__ pattern above).
  for src in "$repo"/agents/*.md; do
    [[ -f "$src" ]] || continue
    cp "$src" "$agents_dir/$(basename "$src")"
  done

  # Skills: copy each <name>/SKILL.md directory.
  for src in "$repo"/skills/*/SKILL.md; do
    [[ -f "$src" ]] || continue
    local skill_name; skill_name=$(basename "$(dirname "$src")")
    mkdir -p "$skills_dir/$skill_name"
    cp "$src" "$skills_dir/$skill_name/SKILL.md"
  done
}

# Remove only the files this repo installs into <project>/.opencode/, then
# clean up now-empty dirs. Leaves unrelated user files untouched.
_jirasik_uninstall_commands_from_project() {
  local repo="$1"
  local project_dir="$2"
  local commands_dir="${project_dir%/}/.opencode/commands"
  local agents_dir="${project_dir%/}/.opencode/agents"
  local skills_dir="${project_dir%/}/.opencode/skills"

  for src in "$repo"/commands/*.md; do
    [[ -f "$src" ]] || continue
    rm -f "$commands_dir/$(basename "$src")"
  done
  for src in "$repo"/agents/*.md; do
    [[ -f "$src" ]] || continue
    rm -f "$agents_dir/$(basename "$src")"
  done
  for src in "$repo"/skills/*/SKILL.md; do
    [[ -f "$src" ]] || continue
    local skill_name; skill_name=$(basename "$(dirname "$src")")
    local skill_subdir="$skills_dir/$skill_name"
    rm -f "$skill_subdir/SKILL.md"
    rmdir "$skill_subdir" 2>/dev/null
  done

  rmdir "$commands_dir" "$agents_dir" "$skills_dir" 2>/dev/null
  rmdir "${project_dir%/}/.opencode" 2>/dev/null
}

# --- Pi (https://pi.dev) support ---------------------------------------------
# Pi has no per-project install: prompt templates (/commands) and skills live
# under ~/.pi/agent/. Prompts are *generated* from commands/*.md because Pi has
# no `!`cmd`` shell injection and no `agent:` frontmatter:
#   - `!`cmd``  -> instruction telling the model to run cmd via bash
#   - `agent: X` -> dropped; body told to delegate via the subagent tool, which
#                  reads the agent definition from ~/.jirasik/agents/X.md
# Skills are symlinked; agent definitions are symlinked into ~/.jirasik/agents.

_jirasik_pi_dir() { printf '%s' "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"; }

# Convert one OpenCode command file to a Pi prompt template on stdout.
_jirasik_pi_convert_command() {
  local src="$1" jira_url="${2:-}"
  local uses_agents=false
  grep -qE '^agent:|branch-review|pr-review|review-vetter' "$src" && uses_agents=true

  # Frontmatter (minus `agent:`), then optional preamble, then body.
  awk -v uses_agents="$uses_agents" '
    BEGIN { fm = 0 }
    /^---$/ && fm < 2 {
      fm++
      print
      if (fm == 2 && uses_agents == "true") {
        print ""
        print "> **Pi note:** this prompt was written for OpenCode. Wherever it says to run a"
        print "> `Task`/subagent named `X` (or to hand off to agent `X`), call the `subagent` tool"
        print "> (type `general-purpose`) with a prompt that tells it to first read"
        print "> `~/.jirasik/agents/X.md` and follow it as its instructions (ignore that file'"'"'s"
        print "> frontmatter), passing along the inputs described here. Subagents must stay"
        print "> read-only: no file edits, only read-only git/gh commands."
        print "> Items marked [run with bash: ...] are for you to run with bash, using the output."
        print ""
      }
      next
    }
    fm == 1 && /^agent:/ { agent = $2; next }
    { print }
    END { }
  ' "$src" | {
    # Replace !`cmd` with an explicit run-this instruction; fill __JIRA_URL__.
    sed -E 's/!`([^`]+)`/[run with bash: `\1`]/g' | sed "s|__JIRA_URL__|$jira_url|g"
  }
  local agent; agent=$(awk '/^---$/{n++} n==1 && /^agent:/{print $2}' "$src")
  if [[ -n "$agent" ]]; then
    printf '\nDelegate the review to the `%s` agent per the Pi note above (instructions in `~/.jirasik/agents/%s.md`).\n' "$agent" "$agent"
  fi
}

_jirasik_install_pi() {
  local repo="$1" jira_url="${2:-}"
  local pi; pi=$(_jirasik_pi_dir)
  [[ -d "$pi" ]] || return 0          # Pi not installed: nothing to do

  mkdir -p "$pi/prompts" "$pi/skills" "$HOME/.jirasik/agents"

  local src name
  for src in "$repo"/commands/*.md; do
    [[ -f "$src" ]] || continue
    name=$(basename "$src")
    _jirasik_pi_convert_command "$src" "$jira_url" > "$pi/prompts/$name"
  done
  for src in "$repo"/agents/*.md; do
    [[ -f "$src" ]] || continue
    ln -sf "$src" "$HOME/.jirasik/agents/$(basename "$src")"
  done
  for src in "$repo"/skills/*/; do
    [[ -f "${src}SKILL.md" ]] || continue
    ln -sfn "${src%/}" "$pi/skills/$(basename "$src")"
  done
}

_jirasik_uninstall_pi() {
  local repo="$1"
  local pi; pi=$(_jirasik_pi_dir)
  local src
  for src in "$repo"/commands/*.md; do
    [[ -f "$src" ]] && rm -f "$pi/prompts/$(basename "$src")"
  done
  for src in "$repo"/agents/*.md; do
    [[ -f "$src" ]] && rm -f "$HOME/.jirasik/agents/$(basename "$src")"
  done
  for src in "$repo"/skills/*/; do
    [[ -L "$pi/skills/$(basename "$src")" ]] && rm -f "$pi/skills/$(basename "$src")"
  done
  return 0
}
