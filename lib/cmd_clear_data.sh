#!/usr/bin/env bash
# bagitops clear-data <service>

cmd_clear_data() {
  [[ $# -eq 1 ]] || { printf "Usage: bagitops clear-data <service>\n" >&2; exit 1; }
  local service="$1"

  require_cmd docker
  load_config

  local compose_file="$BAGITOPS_REPO_DIR/docker-compose.yml"
  [[ -f "$compose_file" ]] || die "docker-compose.yml not found — run 'bagitops pull' first"

  # Collect bind-mount host paths for this specific service
  local mounts=()
  mapfile -t mounts < <(compose_bind_mounts "$compose_file" "$service")

  if [[ ${#mounts[@]} -eq 0 ]]; then
    die "no bind-mount volumes found for service '$service'"
  fi

  printf "\n  ${BOLD}Stopping service '%s'...${RESET}\n" "$service" >&2
  if docker compose version &>/dev/null 2>&1; then
    docker compose -f "$compose_file" stop "$service" &>/dev/null
  else
    docker-compose -f "$compose_file" stop "$service" &>/dev/null
  fi
  printf "  ${GREEN}✓${RESET}  stopped\n" >&2

  printf "\n  ${BOLD}Clearing volume data...${RESET}\n" >&2
  for rel in "${mounts[@]}"; do
    local abs="$BAGITOPS_REPO_DIR/$rel"
    if [[ -d "$abs" ]]; then
      rm -rf "$abs"
      mkdir -p "$abs"
      printf "  ${GREEN}✓${RESET}  cleared %s\n" "$rel" >&2
    else
      mkdir -p "$abs"
      printf "  ${DIM}      %s (was empty)${RESET}\n" "$rel" >&2
    fi
  done

  printf "\n  Run ${BOLD}bagitops run${RESET} to restart containers.\n\n" >&2
}
