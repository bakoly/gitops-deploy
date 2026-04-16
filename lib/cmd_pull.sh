#!/usr/bin/env bash
# bagitops pull

cmd_pull() {
  local force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=1; shift ;;
      *) die "unknown option: $1 — usage: bagitops pull [--force]" ;;
    esac
  done

  require_cmd git

  load_config

  local repo_url="${BAGITOPS_REPO_URL:-}"
  local ssh_key="${BAGITOPS_SSH_KEY:-}"

  [[ -n "$repo_url" ]] || die "no repo URL in config — re-run 'bagitops init <name> <url>'"

  # ConnectTimeout only limits SSH handshake, not ongoing data transfers
  local git_ssh_cmd=""
  if [[ -n "$ssh_key" ]]; then
    [[ -f "$ssh_key" ]] || die "ssh key not found: $ssh_key"
    git_ssh_cmd="ssh -i $ssh_key -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=15"
  fi

  local repo_dir="$BAGITOPS_REPO_DIR"
  local parts_dir="$repo_dir/imageparts"   # git clone lives here
  local last_commit_file="$repo_dir/last-commit"

  # --- Check remote HEAD against cached commit (skip pull if unchanged) ---
  local remote_sha cached_sha=""
  if [[ $force -eq 1 ]]; then
    printf "  ${DIM}[1/5] skipping HEAD check (--force)${RESET}\n" >&2
  else
    printf "  ${DIM}[1/5] checking remote HEAD...${RESET}\n" >&2
    remote_sha="$(GIT_SSH_COMMAND="$git_ssh_cmd" GIT_TERMINAL_PROMPT=0 git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1)"
    [[ -f "$last_commit_file" ]] && cached_sha="$(cat "$last_commit_file")"

    if [[ -n "$remote_sha" ]]; then
      printf "  ${DIM}      remote: %.12s${RESET}\n" "$remote_sha" >&2
      printf "  ${DIM}      cached: %s${RESET}\n" "${cached_sha:+"$(printf '%.12s' "$cached_sha")"}" >&2
    else
      printf "  ${DIM}      could not reach remote — proceeding with sync${RESET}\n" >&2
    fi

    if [[ -n "$remote_sha" && "$remote_sha" == "$cached_sha" ]]; then
      # Only skip if assembled tars are still present (not yet consumed by run)
      local _existing_tars=()
      mapfile -t _existing_tars < <(find "$repo_dir" -maxdepth 1 -type f -name "*.tar" 2>/dev/null)
      if [[ ${#_existing_tars[@]} -gt 0 ]]; then
        printf "  ${GREEN}✓${RESET}  Already up to date ${DIM}(%.12s)${RESET}\n" "$remote_sha" >&2
        printf "\n  Run ${BOLD}bagitops run${RESET} to load images and start containers.\n\n" >&2
        return 0
      fi
      printf "  ${DIM}      up to date but images missing — re-assembling${RESET}\n" >&2
    fi
  fi

  mkdir -p "$parts_dir"

  # --- Sync repo into imageparts/ ---
  printf "  ${DIM}[2/5] syncing repo...${RESET}\n" >&2
  spinner_start "Syncing repo..."
  if [[ $force -eq 0 && -d "$parts_dir/.git" ]]; then
    printf "  ${DIM}      updating existing clone${RESET}\n" >&2
    GIT_SSH_COMMAND="$git_ssh_cmd" GIT_TERMINAL_PROMPT=0 \
      git -C "$parts_dir" remote set-url origin "$repo_url" &>/dev/null
    GIT_SSH_COMMAND="$git_ssh_cmd" GIT_TERMINAL_PROMPT=0 \
      git -C "$parts_dir" fetch --depth 1 origin 2>&1 | tail -3 >&2 || \
      die "git fetch failed — check SSH key and repo URL"
    git -C "$parts_dir" reset --hard FETCH_HEAD &>/dev/null
  else
    printf "  ${DIM}      fresh clone${RESET}\n" >&2
    rm -rf "$parts_dir"
    GIT_SSH_COMMAND="$git_ssh_cmd" GIT_TERMINAL_PROMPT=0 \
      git clone --depth 1 "$repo_url" "$parts_dir" 2>&1 | tail -3 >&2 || \
      die "git clone failed — check SSH key and repo URL"
  fi
  spinner_stop "Repo synced"

  local head_sha
  head_sha="$(git -C "$parts_dir" rev-parse HEAD 2>/dev/null)"
  printf "  ${DIM}      commit: %.12s${RESET}\n" "$head_sha" >&2

  # --- Discover image sets ---
  # Group chunk files by archive name (strip trailing .NNN numeric suffix).
  # e.g. imageparts/cc-org-api.tar.000 → cc-org-api.tar
  printf "  ${DIM}[3/5] discovering image chunks...${RESET}\n" >&2
  local archives=()
  mapfile -t archives < <(
    find "$parts_dir" -maxdepth 1 -type f -name "*.tar.*" \
      | sed 's/\.[0-9][0-9]*$//' \
      | sort -u \
      | xargs -I{} basename {}
  )
  [[ ${#archives[@]} -gt 0 ]] || die "no image chunks found in imageparts/"
  printf "  ${DIM}      found %d archive(s): %s${RESET}\n" "${#archives[@]}" "${archives[*]}" >&2

  # --- Assemble all tar files (chunks → complete tars in repo_dir/) ---
  printf "  ${DIM}[4/5] assembling tar files...${RESET}\n" >&2
  for archive in "${archives[@]}"; do
    local image_tar="$repo_dir/$archive"   # direct child of bagitops-repo/

    local chunks=()
    mapfile -t chunks < <(find "$parts_dir" -maxdepth 1 -name "${archive}.*" -type f | sort)
    printf "  ${DIM}      %s: %d chunk(s)${RESET}\n" "$archive" "${#chunks[@]}" >&2

    [[ ${#chunks[@]} -gt 0 ]] || die "no chunks found for archive: $archive"

    rm -f "$image_tar"
    local i=0
    for chunk in "${chunks[@]}"; do
      i=$(( i + 1 ))
      if ! cat "$chunk" >> "$image_tar"; then
        die "failed to assemble chunk: $chunk into $image_tar"
      fi
      progress_bar "$i" "${#chunks[@]}" "assembling $archive"
    done

    # Validate assembled tar file
    if ! tar -tzf "$image_tar" &>/dev/null; then
      die "assembled tar file is corrupted: $image_tar"
    fi
  done

  # --- Promote docker-compose.yml, validate, then wipe imageparts/ ---
  printf "  ${DIM}[5/5] finalising...${RESET}\n" >&2
  local compose_src="$parts_dir/docker-compose.yml"
  [[ -f "$compose_src" ]] || die "docker-compose.yml not found in imageparts/ — incomplete repo?"
  cp "$compose_src" "$repo_dir/docker-compose.yml"
  check_bind_mount_paths "$repo_dir/docker-compose.yml"

  if [[ -n "$head_sha" ]]; then
    printf '%s\n' "$head_sha" > "$last_commit_file"
  fi

  spinner_start "Removing imageparts/..."
  rm -rf "$parts_dir"
  spinner_stop "imageparts/ removed"

  printf "\n  Run ${BOLD}bagitops run${RESET} to load images and start containers.\n\n" >&2
}
