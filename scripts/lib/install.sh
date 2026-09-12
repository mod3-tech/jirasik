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

  # Skills: copy into <name>/SKILL.md subdirectory.
  for src in "$repo"/skills/*.md; do
    [[ -f "$src" ]] || continue
    local skill_name="${src##*/}"
    skill_name="${skill_name%.md}"
    local skill_subdir="$skills_dir/$skill_name"
    mkdir -p "$skill_subdir"
    cp "$src" "$skill_subdir/SKILL.md"
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
  for src in "$repo"/skills/*.md; do
    [[ -f "$src" ]] || continue
    local skill_name="${src##*/}"
    skill_name="${skill_name%.md}"
    local skill_subdir="$skills_dir/$skill_name"
    rm -f "$skill_subdir/SKILL.md"
    rmdir "$skill_subdir" 2>/dev/null
  done

  rmdir "$commands_dir" "$agents_dir" "$skills_dir" 2>/dev/null
  rmdir "${project_dir%/}/.opencode" 2>/dev/null
}
