#!/usr/bin/env bash
# bagitops update — pull latest from the CLI repo itself

CLI_DIR="$HOME/.bagitops/cli"

cmd_update() {
  require_cmd git

  [[ -d "$CLI_DIR/.git" ]] || die "bagitops CLI repo not found at $CLI_DIR — reinstall via the install script"

  spinner_start "Updating bagitops..."
  git -C "$CLI_DIR" pull --ff-only &>/dev/null
  spinner_stop "bagitops up to date"
}
