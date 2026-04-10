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

if ! command -v firefox &>/dev/null; then
  if command -v brew &>/dev/null; then
    gum style --foreground=1 "Firefox not found. Installing..."
    brew install --cask firefox
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
# jirasik configuration
JIRA_URL="$JIRA_URL"
PROJECT_DIR="$PROJECT_DIR"
EOF

# --- 3b. Initialize Firefox profile ---
PROFILE_DIR="$INSTALL_DIR/firefox-profile"
if [[ ! -f "$PROFILE_DIR/times.json" ]]; then
  $QUIET || gum style "Initializing Firefox profile..."
  mkdir -p "$PROFILE_DIR"
  # -CreateProfile registers a named profile and initializes the directory
  firefox -CreateProfile "jirasik $PROFILE_DIR" 2>/dev/null
  if [[ ! -f "$PROFILE_DIR/times.json" ]]; then
    gum style --foreground=1 "Failed to initialize Firefox profile."
    gum style "Try running: firefox -CreateProfile \"jirasik $PROFILE_DIR\""
    exit 1
  fi
fi

# --- 4. Verify authentication ---
source "$SCRIPT_DIR/scripts/auth.sh"
if [[ -z "$TOKEN" ]]; then
  gum style --foreground=3 "No active session found. Opening Firefox to authenticate..."
  pkill -f "[Ff]irefox" 2>/dev/null
  sleep 2
  firefox -profile "$PROFILE_DIR" "$JIRA_URL" &
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

# --- 5. Copy scripts ---
for script in "$SCRIPT_DIR"/scripts/*.sh; do
  cp "$script" "$INSTALL_DIR/$(basename "$script")"
  chmod +x "$INSTALL_DIR/$(basename "$script")"
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

# --- 6. Install OpenCode commands and agents ---
COMMANDS_DIR="${PROJECT_DIR%/}/.opencode/commands"
AGENTS_DIR="${PROJECT_DIR%/}/.opencode/agents"
mkdir -p "$COMMANDS_DIR" "$AGENTS_DIR"

sed "s|__JIRA_URL__|$JIRA_URL|g" "$SCRIPT_DIR/commands/jira.md" > "$COMMANDS_DIR/jira.md"
sed "s|__JIRA_URL__|$JIRA_URL|g" "$SCRIPT_DIR/commands/todos.md" > "$COMMANDS_DIR/todos.md"
cp "$SCRIPT_DIR/commands/move.md" "$COMMANDS_DIR/move.md"
cp "$SCRIPT_DIR/commands/pr.md" "$COMMANDS_DIR/pr.md"
cp "$SCRIPT_DIR/commands/create-ticket.md" "$COMMANDS_DIR/create-ticket.md"
cp "$SCRIPT_DIR/agents/pr-review.md" "$AGENTS_DIR/pr-review.md"

$QUIET || gum style --bold --foreground=2 "Done!"
