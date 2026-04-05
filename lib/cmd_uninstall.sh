#!/usr/bin/env bash
# bagitops uninstall

LAUNCHER="/usr/local/bin/bagitops"

cmd_uninstall() {
  printf "\n  ${BOLD}Uninstalling bagitops...${RESET}\n\n" >&2

  printf "  removing %s (requires sudo)...\n" "$LAUNCHER" >&2
  sudo rm -f "$LAUNCHER"
  printf "  ${GREEN}✓${RESET}  removed %s\n" "$LAUNCHER" >&2

  printf "  removing %s...\n" "$BAGITOPS_CLI_DIR" >&2
  rm -rf "$BAGITOPS_CLI_DIR"
  printf "  ${GREEN}✓${RESET}  removed %s\n" "$BAGITOPS_CLI_DIR" >&2

  printf "\n  Goodbye.\n\n" >&2
}
