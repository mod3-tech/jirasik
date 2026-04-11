#!/bin/bash
# Shared test setup for adf.sh tests

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Source the ADF library to get the filter variables
source "$REPO_ROOT/scripts/lib/adf.sh"

# Helper: run the comment-body filter (input has .body.content[])
run_adf() {
  echo "$1" | jq -r "$ADF_TO_MD_FILTER"
}

# Helper: run the description filter (input has .fields.description.content[])
run_adf_desc() {
  echo "$1" | jq -r "$ADF_DESC_TO_MD_FILTER"
}

# Helper: wrap content[] in a comment body envelope
wrap_body() {
  cat <<EOF
{"body":{"type":"doc","version":1,"content":[$1]}}
EOF
}

# Helper: wrap content[] in an issue description envelope
wrap_desc() {
  cat <<EOF
{"fields":{"description":{"type":"doc","version":1,"content":[$1]}}}
EOF
}
