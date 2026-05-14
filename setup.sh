#!/usr/bin/env bash

QUIET=false
if [[ "${1:-}" == "-q" ]] || [[ "${1:-}" == "--quiet" ]]; then
  QUIET=true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/scripts/fetch_ticket.sh" ]]; then
  gum style --foreground=1 "Error: Run from the opencode-jira-firefox directory"
  exit 1
fi
INSTALL_DIR="$HOME/.jirasik"
CONFIG_FILE="$INSTALL_DIR/config"
PROJECTS_FILE="$INSTALL_DIR/projects"

IS_UPDATE=false
if [[ -f "$CONFIG_FILE" ]]; then
  IS_UPDATE=true
fi

# --- Project list helpers ---

_load_projects() {
  if [[ -f "$PROJECTS_FILE" ]]; then
    grep -v '^#' "$PROJECTS_FILE" | grep -v '^$'
  fi
}

_project_count() {
  _load_projects | wc -l | tr -d ' '
}

_project_exists() {
  local dir="$1"
  _load_projects | grep -qxF "$dir"
}

_add_project() {
  local dir="$1"
  if ! _project_exists "$dir"; then
    echo "$dir" >> "$PROJECTS_FILE"
  fi
}

_remove_project() {
  local dir="$1"
  if [[ -f "$PROJECTS_FILE" ]]; then
    local tmp
    tmp=$(mktemp)
    grep -vxF "$dir" "$PROJECTS_FILE" > "$tmp"
    mv "$tmp" "$PROJECTS_FILE"
  fi
}

_install_commands_to_project() {
  local project_dir="$1"
  local jira_url="$2"
  local commands_dir="${project_dir%/}/.opencode/commands"
  local agents_dir="${project_dir%/}/.opencode/agents"
  local skills_dir="${project_dir%/}/.opencode/skills"
  mkdir -p "$commands_dir" "$agents_dir" "$skills_dir"

  # Commands: substitute __JIRA_URL__ if present, else plain copy.
  for src in "$SCRIPT_DIR"/commands/*.md; do
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
  for src in "$SCRIPT_DIR"/agents/*.md; do
    [[ -f "$src" ]] || continue
    cp "$src" "$agents_dir/$(basename "$src")"
  done

  # Skills: copy into <name>/SKILL.md subdirectory.
  for src in "$SCRIPT_DIR"/skills/*.md; do
    [[ -f "$src" ]] || continue
    local skill_name="${src##*/}"
    skill_name="${skill_name%.md}"
    local skill_subdir="$skills_dir/$skill_name"
    mkdir -p "$skill_subdir"
    cp "$src" "$skill_subdir/SKILL.md"
  done
}

_uninstall_commands_from_project() {
  local project_dir="$1"
  local commands_dir="${project_dir%/}/.opencode/commands"
  local agents_dir="${project_dir%/}/.opencode/agents"
  local skills_dir="${project_dir%/}/.opencode/skills"

  # Remove only the files this repo installs (don't nuke unrelated user files).
  for src in "$SCRIPT_DIR"/commands/*.md; do
    [[ -f "$src" ]] || continue
    rm -f "$commands_dir/$(basename "$src")"
  done
  for src in "$SCRIPT_DIR"/agents/*.md; do
    [[ -f "$src" ]] || continue
    rm -f "$agents_dir/$(basename "$src")"
  done
  for src in "$SCRIPT_DIR"/skills/*.md; do
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

_list_projects_display() {
  local i=1
  while IFS= read -r p; do
    echo "  $i. $p"
    ((i++))
  done < <(_load_projects)
}

# --- 1. Check prerequisites ---
MISSING=()
GUM_MISSING=false
for cmd in jq sqlite3 curl gum; do
  if ! command -v "$cmd" &>/dev/null; then
    if [[ "$cmd" == "gum" ]]; then
      GUM_MISSING=true
    else
      MISSING+=("$cmd")
    fi
  fi
done

# Source Firefox helper library
source "$SCRIPT_DIR/scripts/lib/firefox.sh"

if ! _ff_find; then
  if command -v brew &>/dev/null; then
    gum style --foreground=1 "Firefox not found. Installing..."
    brew install --cask firefox
    if ! _ff_find; then
      gum style --foreground=1 "Firefox installed but not detected. Check your PATH."
      exit 1
    fi
  else
    gum style --foreground=1 "Firefox not found and Homebrew not available."
    gum style "Install Firefox manually: https://www.mozilla.org/firefox"
    exit 1
  fi
fi

if ! command -v glow &>/dev/null; then
  if command -v brew &>/dev/null; then
    $QUIET || gum style "Installing glow..."
    brew install glow
  fi
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  gum style --foreground=1 "Missing required tools: ${MISSING[*]}"
  gum style "Install them and re-run this script."
  exit 1
fi

if $GUM_MISSING; then
  gum style --foreground=3 "gum -- not found"
  if command -v brew &>/dev/null; then
    gum style "Installing gum with Homebrew..."
    brew install gum
  else
    gum style --foreground=1 "Homebrew not found. Install gum manually: https://github.com/charmbracelet/gum"
    exit 1
  fi
fi

if ! command -v lolcat &>/dev/null; then
  if command -v brew &>/dev/null; then
    $QUIET || echo "Installing lolcat..."
    brew install lolcat
  fi
fi

if ! command -v bunx &>/dev/null && ! command -v npx &>/dev/null; then
  gum style --foreground=1 "bunx/npx not found. Install bun or Node.js."
  exit 1
fi

if ! $QUIET && ! $IS_UPDATE; then
  gum style --bold "Setting up..."
fi

# --- 2. Configuration ---

# Migrate old single PROJECT_DIR to projects file
_migrate_legacy_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -n "${PROJECT_DIR:-}" ]] && [[ ! -f "$PROJECTS_FILE" ]]; then
      echo "$PROJECT_DIR" > "$PROJECTS_FILE"
    fi
  fi
}

if $IS_UPDATE; then
  _migrate_legacy_config
  source "$CONFIG_FILE"
  EXISTING_URL="${JIRA_URL:-}"
  EXISTING_SUBDOMAIN="${EXISTING_URL##https://}"
  EXISTING_SUBDOMAIN="${EXISTING_SUBDOMAIN%.atlassian.net}"

  MODE=$(gum choose \
    "Update (keep current settings)" \
    "Add a project" \
    "Remove a project" \
    "Configure" \
    "Uninstall" \
    "Cancel")

  if [[ -z "$MODE" || "$MODE" == "Cancel" ]]; then
    exit 0
  fi

  if [[ "$MODE" == "Uninstall" ]]; then
    gum style --bold "The following will be removed:"
    echo ""
    gum style "  • $INSTALL_DIR/"
    echo "    (config, scripts, lib, firefox-profile)"
    echo "  • $HOME/bin/jirasik"
    echo ""
    COUNT=$(_project_count)
    if [[ "$COUNT" -gt 0 ]]; then
      gum style "  Commands will be removed from $COUNT project(s):"
      _list_projects_display
      echo ""
    fi

    if gum confirm "Remove jirasik?"; then
      while IFS= read -r proj; do
        _uninstall_commands_from_project "$proj"
      done < <(_load_projects)
      rm -rf "$INSTALL_DIR"
      rm -f "$HOME/bin/jirasik"
      gum style --foreground=2 "Uninstalled."
    else
      gum style "Cancelled."
    fi
    exit 0
  fi

  if [[ "$MODE" == "Add a project" ]]; then
    COUNT=$(_project_count)
    if [[ "$COUNT" -gt 0 ]]; then
      gum style "Current projects:"
      _list_projects_display
      echo ""
    fi

    while true; do
      NEW_PROJECT=$(gum input --prompt "Project directory: " --placeholder "/path/to/project" --value "$(pwd)")
      if [[ -z "$NEW_PROJECT" ]]; then
        gum style --foreground=3 "Directory can't be empty"
        continue
      fi
      if ! [[ -d "$NEW_PROJECT" ]]; then
        gum style --foreground=3 "Directory does not exist: $NEW_PROJECT"
        continue
      fi
      if _project_exists "$NEW_PROJECT"; then
        gum style --foreground=3 "Already registered: $NEW_PROJECT"
        continue
      fi
      break
    done

    JIRA_URL="$EXISTING_URL"
    _add_project "$NEW_PROJECT"
    _install_commands_to_project "$NEW_PROJECT" "$JIRA_URL"
    gum style --foreground=2 "Added: $NEW_PROJECT"

    COUNT=$(_project_count)
    gum style "Registered projects ($COUNT):"
    _list_projects_display
    exit 0
  fi

  if [[ "$MODE" == "Remove a project" ]]; then
    COUNT=$(_project_count)
    if [[ "$COUNT" -eq 0 ]]; then
      gum style --foreground=3 "No projects registered."
      exit 0
    fi

    gum style "Select a project to remove:"
    # Build array of projects for gum choose
    PROJ_LIST=()
    while IFS= read -r p; do
      PROJ_LIST+=("$p")
    done < <(_load_projects)

    SELECTED=$(printf '%s\n' "${PROJ_LIST[@]}" | gum choose)
    if [[ -z "$SELECTED" ]]; then
      gum style "Cancelled."
      exit 0
    fi

    if gum confirm "Remove commands from $SELECTED and unregister it?"; then
      _uninstall_commands_from_project "$SELECTED"
      _remove_project "$SELECTED"
      gum style --foreground=2 "Removed: $SELECTED"

      COUNT=$(_project_count)
      if [[ "$COUNT" -gt 0 ]]; then
        gum style "Remaining projects ($COUNT):"
        _list_projects_display
      else
        gum style --foreground=3 "No projects remaining."
      fi
    else
      gum style "Cancelled."
    fi
    exit 0
  fi

  if [[ "$MODE" == "Configure" ]]; then
    IS_UPDATE=false
  else
    # "Update (keep current settings)" — just use existing URL, fall through
    JIRA_URL="$EXISTING_URL"
  fi
fi

if ! $IS_UPDATE; then
  # Jira subdomain
  while true; do
    SUBDOMAIN=$(gum input --prompt "Jira subdomain: " --placeholder "yourcompany" --value "${EXISTING_SUBDOMAIN:-}")
    if [[ -n "$SUBDOMAIN" ]]; then
      break
    fi
    gum style --foreground=3 "Subdomain can't be empty"
  done
  JIRA_URL="https://${SUBDOMAIN}.atlassian.net"

  # Project directory for OpenCode commands
  DEFAULT_PROJECT="$(pwd)"
  NEW_PROJECT=$(gum input --prompt "Project directory: " --placeholder "$DEFAULT_PROJECT" --value "$DEFAULT_PROJECT")
  if [[ -z "$NEW_PROJECT" ]]; then
    NEW_PROJECT="$DEFAULT_PROJECT"
  fi
fi

# --- 3. Create install directory ---
mkdir -p "$INSTALL_DIR"

cat > "$INSTALL_DIR/config" <<EOF
# jirasik configuration
JIRA_URL="$JIRA_URL"
EOF

# Register the project (fresh install or reconfigure)
if [[ -n "${NEW_PROJECT:-}" ]]; then
  _add_project "$NEW_PROJECT"
fi

# --- 3b. Initialize Firefox profile ---
PROFILE_DIR="$INSTALL_DIR/firefox-profile"
if ! _ff_profile_ok "$PROFILE_DIR"; then
  $QUIET || gum style "Initializing Firefox profile..."
  if ! _ff_init_profile "$PROFILE_DIR"; then
    gum style --foreground=1 "Failed to initialize Firefox profile."
    exit 1
  fi
fi

# --- 4. Verify authentication ---
source "$SCRIPT_DIR/scripts/auth.sh"
if [[ -z "$TOKEN" ]]; then
  gum style --foreground=3 "No active session found. Opening Firefox to authenticate..."
  _ff_open_profile "$PROFILE_DIR" "$JIRA_URL"
  gum style "Log in to Jira, then close Firefox and re-run setup."
  exit 1
fi

TEST_RESP=$(curl -sL -b "tenant.session.token=$TOKEN" "${JIRA_URL}/rest/api/3/myself")
if echo "$TEST_RESP" | jq -e '.accountId' >/dev/null 2>&1; then
  $QUIET || gum style --foreground=2 "  ✓ Authenticated"
else
  gum style --foreground=1 "Authentication failed."
  rm -f "$INSTALL_DIR/session_token"
  exit 1
fi

# --- 5. Link scripts ---
# Symlink scripts/ from the repo into the install dir so a `git pull` in the
# checkout immediately propagates without re-running setup. Previous versions
# copied; that caused silent drift bugs when users (or agents) trusted the
# stale installed copy. Migrate any existing copies to symlinks in-place.
mkdir -p "$INSTALL_DIR/scripts/lib"

# Migration: if scripts/ contains regular files, replace with symlinks.
# We symlink each .sh individually rather than the whole directory so that
# lib/ stays a real dir (some installs may shadow individual files later).
MIGRATED_COUNT=0
LINKED_COUNT=0
for script in "$SCRIPT_DIR"/scripts/*.sh; do
  dest="$INSTALL_DIR/scripts/$(basename "$script")"
  if [[ -L "$dest" ]]; then
    # Already a symlink — verify it points at the right place
    if [[ "$(readlink "$dest")" != "$script" ]]; then
      ln -sf "$script" "$dest"
      LINKED_COUNT=$((LINKED_COUNT + 1))
    fi
  elif [[ -e "$dest" ]]; then
    # Existing regular file (copy from a previous setup.sh run) — replace
    rm -f "$dest"
    ln -sf "$script" "$dest"
    MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
  else
    ln -sf "$script" "$dest"
    LINKED_COUNT=$((LINKED_COUNT + 1))
  fi
done
for lib in "$SCRIPT_DIR"/scripts/lib/*.sh; do
  dest="$INSTALL_DIR/scripts/lib/$(basename "$lib")"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" != "$lib" ]]; then
      ln -sf "$lib" "$dest"
      LINKED_COUNT=$((LINKED_COUNT + 1))
    fi
  elif [[ -e "$dest" ]]; then
    rm -f "$dest"
    ln -sf "$lib" "$dest"
    MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
  else
    ln -sf "$lib" "$dest"
    LINKED_COUNT=$((LINKED_COUNT + 1))
  fi
done

# Clean up stale flat scripts from old layout
for old_script in "$INSTALL_DIR"/*.sh; do
  [[ -f "$old_script" ]] && rm -f "$old_script"
done
# Clean up orphaned top-level lib/ (now lives under scripts/lib/)
[[ -d "$INSTALL_DIR/lib" ]] && ! [[ -L "$INSTALL_DIR/lib" ]] && rm -rf "$INSTALL_DIR/lib"

if ! $QUIET; then
  if [[ $MIGRATED_COUNT -gt 0 ]]; then
    gum style --foreground=3 "  ✓ Migrated $MIGRATED_COUNT script(s) from copy → symlink"
    gum style --foreground=8 "    Future repo updates apply immediately — no more re-running setup.sh just to refresh code."
  fi
  if [[ $LINKED_COUNT -gt 0 ]]; then
    gum style --foreground=2 "  ✓ Linked $LINKED_COUNT script(s) from $SCRIPT_DIR/scripts/"
  elif [[ $MIGRATED_COUNT -eq 0 ]]; then
    gum style --foreground=8 "  ✓ Scripts already linked"
  fi
fi

if [[ -f "$SCRIPT_DIR/bin/jirasik" ]]; then
  # Symlink (not copy) so repo changes propagate without re-running setup.
  if [[ -e "$INSTALL_DIR/jirasik" && ! -L "$INSTALL_DIR/jirasik" ]]; then
    rm -f "$INSTALL_DIR/jirasik"
  fi
  ln -sf "$SCRIPT_DIR/bin/jirasik" "$INSTALL_DIR/jirasik"

  mkdir -p "$HOME/bin"
  ln -sf "$INSTALL_DIR/jirasik" "$HOME/bin/jirasik"

  if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    if [[ "$SHELL" == *fish* ]] || command -v fish &>/dev/null; then
      gum style --foreground=3 "Note: ~/bin not in PATH. Run: fish_add_path -g \$HOME/bin"
    else
      gum style --foreground=3 "Note: ~/bin not in PATH. Run: export PATH=\"\$HOME/bin:\$PATH\""
    fi
  fi
fi

# --- 6. Install OpenCode commands and agents to all projects ---
while IFS= read -r proj; do
  _install_commands_to_project "$proj" "$JIRA_URL"
  $QUIET || gum style --foreground=2 "  ✓ Commands installed: $proj"
done < <(_load_projects)

COUNT=$(_project_count)
$QUIET || gum style --bold --foreground=2 "Done! ($COUNT project(s) configured)"
