#!/usr/bin/env bash
# bagitops uninstall

LAUNCHER="/usr/local/bin/bagitops"

cmd_uninstall() {
  printf "\n  ${BOLD}Uninstalling bagitops...${RESET}\n\n" >&2

  if [[ -f "$LAUNCHER" ]]; then
    spinner_start "Removing launcher..."
    if [[ -w "$LAUNCHER" ]]; then
      rm -f "$LAUNCHER"
    else
      command -v sudo &>/dev/null || { spinner_fail "cannot remove $LAUNCHER"; die "'sudo' is not available"; }
      sudo rm -f "$LAUNCHER"
    fi
    spinner_stop "Removed $LAUNCHER"
  fi

  if [[ -d "$BAGITOPS_CLI_DIR" ]]; then
    spinner_start "Removing CLI directory..."
    rm -rf "$BAGITOPS_CLI_DIR"
    spinner_stop "Removed $BAGITOPS_CLI_DIR"
  fi

  printf "\n  Goodbye.\n\n" >&2
}
