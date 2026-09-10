#!/usr/bin/env bash
set -euo pipefail

KEY="${1:-}"
TITLE="${2:-}"

if [[ -z "$KEY" || -z "$TITLE" ]]; then
  echo "Usage: branch_name.sh <TICKET-KEY> <TITLE>" >&2
  exit 1
fi

SLUG=$(printf '%s' "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g' \
  | sed 's/--*/-/g' \
  | sed 's/^-//;s/-$//')

printf '%s-%s\n' "$KEY" "$SLUG"
