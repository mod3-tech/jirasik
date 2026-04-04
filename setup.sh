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
INSTALL_DIR="$HOME/.firefox-mcp-jira"
CONFIG_FILE="$INSTALL_DIR/config"

IS_UPDATE=false
if [[ -f "$CONFIG_FILE" ]]; then
  IS_UPDATE=true
fi

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
if $IS_UPDATE; then
  source "$CONFIG_FILE"
  EXISTING_URL="${JIRA_URL:-}"
  EXISTING_SUBDOMAIN="${EXISTING_URL##https://}"
  EXISTING_SUBDOMAIN="${EXISTING_SUBDOMAIN%.atlassian.net}"
  EXISTING_PROJECT="${PROJECT_DIR:-$(pwd)}"
  MODE=$(gum choose \
    "Update (keep current settings)" \
    "Configure" \
    "Cancel")

  if [[ -z "$MODE" || "$MODE" == "Cancel" ]]; then
    exit 0
  fi

  if [[ "$MODE" == "Configure" ]]; then
    IS_UPDATE=false
  else
    JIRA_URL="$EXISTING_URL"
    PROJECT_DIR="$EXISTING_PROJECT"
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
  DEFAULT_PROJECT="${EXISTING_PROJECT:-$(pwd)}"
  PROJECT_DIR=$(gum input --prompt "Project directory: " --placeholder "$DEFAULT_PROJECT" --value "$DEFAULT_PROJECT")
  if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR="$DEFAULT_PROJECT"
  fi
fi

# --- 3. Create install directory ---
mkdir -p "$INSTALL_DIR"

cat > "$INSTALL_DIR/config" <<EOF
# opencode-jira-firefox configuration
JIRA_URL="$JIRA_URL"
PROJECT_DIR="$PROJECT_DIR"
EOF

for script in auth.sh display-issues.sh fetch_ticket.sh fetch_todos.sh points.sh transition.sh sprint-view.sh; do
  cp "$SCRIPT_DIR/scripts/$script" "$INSTALL_DIR/$script"
  chmod +x "$INSTALL_DIR/$script"
done

if [[ -f "$SCRIPT_DIR/bin/jirasik" ]]; then
  cp "$SCRIPT_DIR/bin/jirasik" "$INSTALL_DIR/jirasik"
  chmod +x "$INSTALL_DIR/jirasik"

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

# --- 4. Install OpenCode commands ---
COMMANDS_DIR="${PROJECT_DIR%/}/.opencode/commands"
mkdir -p "$COMMANDS_DIR"

sed "s|__JIRA_URL__|$JIRA_URL|g" "$SCRIPT_DIR/commands/jira.md" > "$COMMANDS_DIR/jira.md"
sed "s|__JIRA_URL__|$JIRA_URL|g" "$SCRIPT_DIR/commands/todos.md" > "$COMMANDS_DIR/todos.md"
cp "$SCRIPT_DIR/commands/move.md" "$COMMANDS_DIR/move.md"

$QUIET || gum style --bold --foreground=2 "Done!"
