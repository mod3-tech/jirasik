# Shared ANSI color definitions for jirasik scripts.
#
# Auto-detects whether stdout is a TTY. When it isn't (e.g. piped, captured,
# or running under an agent that renders tool output as plain text), all color
# variables are set to empty strings so the visible output is clean text
# without raw escape sequences.
#
# Honors NO_COLOR (https://no-color.org/) and FORCE_COLOR for explicit override.
#
# Source this file with:  source "$SCRIPT_DIR/lib/colors.sh"
# (Safe to source multiple times.)

if [[ -n "${NO_COLOR:-}" ]]; then
  _JIRASIK_USE_COLOR=0
elif [[ -n "${FORCE_COLOR:-}" ]]; then
  _JIRASIK_USE_COLOR=1
elif [[ -t 1 ]]; then
  _JIRASIK_USE_COLOR=1
else
  _JIRASIK_USE_COLOR=0
fi

if [[ "$_JIRASIK_USE_COLOR" == "1" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RST=$'\033[0m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAGENTA=$'\033[35m'
  CYAN=$'\033[36m'
  PURPLE=$'\033[38;5;141m'
else
  BOLD=''
  DIM=''
  RST=''
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  PURPLE=''
fi
