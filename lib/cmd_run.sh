#!/usr/bin/env bash
# bagitops run

# ---------------------------------------------------------------------------
# check_env_files — validate env files referenced by docker-compose.yml
# Dies if any required file is missing; warns about empty/placeholder values.
# ---------------------------------------------------------------------------
check_env_files() {
  local compose_file="$1"
  local repo_dir
  repo_dir="$(dirname "$compose_file")"

  # Extract env_file paths from docker-compose.yml.
  # Handles both inline (env_file: ./envs/foo.env) and list (- ./envs/foo.env) forms.
  local env_files=()
  while IFS= read -r path; do
    # Strip leading/trailing whitespace and quotes
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    path="${path//\"/}"
    path="${path//\'/}"
    [[ -n "$path" ]] && env_files+=("$path")
  done < <(
    grep -oP '(?<=env_file:[ \t]{0,8})\./[^\s"'"'"']+|(?<=- )\./[^\s"'"'"']+(?=.*\.env)' "$compose_file" 2>/dev/null ||
    awk '/env_file:/{found=1; next} found && /^\s*-/{gsub(/^\s*-\s*/,""); gsub(/\s+$/,""); if(/\.env/) print; next} found && !/^\s*-/{found=0}' "$compose_file"
  )

  if [[ ${#env_files[@]} -eq 0 ]]; then
    return 0  # No env_file directives — nothing to check
  fi

  local missing=0
  local warned=0

  for rel_path in "${env_files[@]}"; do
    local abs_path="$repo_dir/$rel_path"
    # Normalise: remove double slashes
    abs_path="${abs_path//\/\///}"

    if [[ ! -f "$abs_path" ]]; then
      printf "  ${RESET}✗  missing env file: %s\n" "$rel_path" >&2
      missing=$(( missing + 1 ))
      continue
    fi

    printf "  ${GREEN}✓${RESET}  %s\n" "$rel_path" >&2

    # Scan for empty or placeholder values
    local lineno=0
    while IFS= read -r line; do
      lineno=$(( lineno + 1 ))
      # Skip comments and blank lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      # Must be KEY=VALUE form
      [[ "$line" =~ ^[^=]+=(.*)$ ]] || continue
      local val="${BASH_REMATCH[1]}"
      local key="${line%%=*}"

      # Empty value
      if [[ -z "$val" ]]; then
        printf "  ${YELLOW}⚠${RESET}  %s: %s is empty\n" "$rel_path" "$key" >&2
        warned=$(( warned + 1 ))
        continue
      fi

      # Placeholder patterns: starts with "your" (case-insensitive), or known sentinels
      local val_lower="${val,,}"
      if [[ "$val_lower" == your* ]] || \
         [[ "$val_lower" == "change-me" ]] || \
         [[ "$val_lower" == "changeme" ]] || \
         [[ "$val_lower" == "todo" ]] || \
         [[ "$val_lower" == "xxx" ]]; then
        printf "  ${YELLOW}⚠${RESET}  %s: %s looks like a placeholder (%s)\n" "$rel_path" "$key" "$val" >&2
        warned=$(( warned + 1 ))
      fi
    done < "$abs_path"
  done

  if [[ $missing -gt 0 ]]; then
    printf "\n  ${RESET}%d env file(s) missing — run 'bagitops setenv <file>' to place them.\n\n" "$missing" >&2
    die "cannot start containers with missing env files"
  fi

  if [[ $warned -gt 0 ]]; then
    printf "\n  ${YELLOW}⚠${RESET}  %d placeholder/empty value(s) detected — containers may misbehave.\n\n" "$warned" >&2
  fi
}

cmd_run() {
  require_cmd docker
  load_config

  local compose_file="$BAGITOPS_REPO_DIR/docker-compose.yml"
  [[ -f "$compose_file" ]] || die "docker-compose.yml not found in $BAGITOPS_REPO_DIR"

  check_bind_mount_paths "$compose_file"

  printf "\n  ${BOLD}Checking env files...${RESET}\n" >&2
  check_env_files "$compose_file"

  # Load any assembled tar images present in repo_dir/
  local tars=()
  mapfile -t tars < <(find "$BAGITOPS_REPO_DIR" -maxdepth 1 -type f -name "*.tar" | sort)
  if [[ ${#tars[@]} -gt 0 ]]; then
    printf "\n  ${BOLD}Loading Docker images...${RESET}\n" >&2
    for image_tar in "${tars[@]}"; do
      local tname; tname="$(basename "$image_tar")"
      spinner_start "Loading $tname..."
      local load_out
      load_out="$(docker load -i "$image_tar" 2>&1)"
      spinner_stop "$tname loaded"
      printf "  ${DIM}%s${RESET}\n" "$load_out" >&2
      rm -f "$image_tar"
    done
  fi

  # Create host-side bind-mount directories so Docker doesn't create them as root
  local mounts=()
  mapfile -t mounts < <(compose_bind_mounts "$compose_file")
  if [[ ${#mounts[@]} -gt 0 ]]; then
    printf "\n  ${BOLD}Preparing volume directories...${RESET}\n" >&2
    for rel in "${mounts[@]}"; do
      local abs="$BAGITOPS_REPO_DIR/$rel"
      # If the path ends with a file extension it's a file mount — only create
      # the parent directory so Docker doesn't turn the filename into a dir.
      if [[ "$rel" =~ \.[a-zA-Z0-9]+$ ]]; then
        mkdir -p "$(dirname "$abs")"
      else
        mkdir -p "$abs"
      fi
      printf "  ${GREEN}✓${RESET}  %s\n" "$rel" >&2
    done
  fi

  local compose_bin=""
  if docker compose version &>/dev/null 2>&1; then
    compose_bin="docker compose"
  elif command -v docker-compose &>/dev/null; then
    compose_bin="docker-compose"
  else
    die "neither 'docker compose' nor 'docker-compose' found"
  fi

  printf "\n  ${BOLD}Recreating containers...${RESET}\n\n" >&2
  if ! $compose_bin -f "$compose_file" up -d --force-recreate; then
    die "docker compose up --force-recreate failed"
  fi
}
