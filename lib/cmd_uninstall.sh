#!/usr/bin/env bash
# bagitops uninstall

LAUNCHER="/usr/local/bin/bagitops"

cmd_uninstall() {
  printf "\n  ${BOLD}Uninstalling bagitops...${RESET}\n\n" >&2

  if [[ -f "$LAUNCHER" ]]; then
    if [[ -w "$LAUNCHER" ]]; then
      spinner_start "Removing launcher..."
      rm -f "$LAUNCHER"
      spinner_stop "Removed $LAUNCHER"
    else
      command -v sudo &>/dev/null || die "'sudo' is not available — cannot remove $LAUNCHER"
      printf "  ${DIM}  sudo required to remove %s${RESET}\n" "$LAUNCHER" >&2
      sudo rm -f "$LAUNCHER"
      printf "  ${GREEN}✓${RESET}  Removed %s\n" "$LAUNCHER" >&2
    fi
  fi

  if [[ -d "$BAGITOPS_CLI_DIR" ]]; then
    spinner_start "Removing CLI directory..."
    rm -rf "$BAGITOPS_CLI_DIR"
    spinner_stop "Removed $BAGITOPS_CLI_DIR"
  fi

  printf "\n  Goodbye.\n\n" >&2
}
