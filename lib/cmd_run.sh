#!/usr/bin/env bash
# bagitops run

cmd_run() {
  require_cmd docker
  load_config

  local compose_file="$BAGITOPS_REPO_DIR/docker-compose.yml"
  [[ -f "$compose_file" ]] || die "docker-compose.yml not found in $BAGITOPS_REPO_DIR"

  spinner_start "Recreating containers..."
  if docker compose version &>/dev/null 2>&1; then
    docker compose -f "$compose_file" up -d --force-recreate &>/dev/null
  elif command -v docker-compose &>/dev/null; then
    docker-compose -f "$compose_file" up -d --force-recreate &>/dev/null
  else
    spinner_fail "no compose tool found"
    die "neither 'docker compose' nor 'docker-compose' found"
  fi
  spinner_stop "Containers running"
}
