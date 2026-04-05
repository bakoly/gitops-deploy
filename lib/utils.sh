#!/usr/bin/env bash
# Shared helpers

BAGITOPS_DIR="$HOME/.bagitops"
CONFIG_FILE="$BAGITOPS_DIR/config"
REPO_DIR="$BAGITOPS_DIR/repo"

die() { echo "error: $*" >&2; exit 1; }

require_cmd() { command -v "$1" &>/dev/null || die "'$1' is required but not found"; }

load_config() {
  [[ -f "$CONFIG_FILE" ]] || die "no config found — run 'bagitops pull <url>' first"
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
}
