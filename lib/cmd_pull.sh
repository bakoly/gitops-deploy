#!/usr/bin/env bash
# bagitops pull

cmd_pull() {
  [[ $# -eq 0 ]] || die "'bagitops pull' takes no arguments — set the repo URL with 'bagitops init'"

  require_cmd git
  require_cmd docker

  load_config

  local repo_url="${BAGITOPS_REPO_URL:-}"
  local ssh_key="${BAGITOPS_SSH_KEY:-}"

  [[ -n "$repo_url" ]] || die "no repo URL in config — re-run 'bagitops init <name> <url>'"

  local git_ssh_cmd=""
  if [[ -n "$ssh_key" ]]; then
    [[ -f "$ssh_key" ]] || die "ssh key not found: $ssh_key"
    git_ssh_cmd="ssh -i $ssh_key -o StrictHostKeyChecking=no -o BatchMode=yes"
  fi

  local repo_dir="$BAGITOPS_REPO_DIR"
  local parts_dir="$repo_dir/imageparts"   # git clone lives here

  mkdir -p "$parts_dir"

  # --- Sync repo into imageparts/ ---
  spinner_start "Syncing repo..."
  if [[ -d "$parts_dir/.git" ]]; then
    if [[ -n "$git_ssh_cmd" ]]; then
      GIT_SSH_COMMAND="$git_ssh_cmd" git -C "$parts_dir" remote set-url origin "$repo_url" &>/dev/null
      GIT_SSH_COMMAND="$git_ssh_cmd" git -C "$parts_dir" fetch --depth 1 origin &>/dev/null
    else
      git -C "$parts_dir" remote set-url origin "$repo_url" &>/dev/null
      git -C "$parts_dir" fetch --depth 1 origin &>/dev/null
    fi
    git -C "$parts_dir" reset --hard FETCH_HEAD &>/dev/null
  else
    rm -rf "$parts_dir"
    if [[ -n "$git_ssh_cmd" ]]; then
      GIT_SSH_COMMAND="$git_ssh_cmd" git clone --depth 1 "$repo_url" "$parts_dir" &>/dev/null
    else
      git clone --depth 1 "$repo_url" "$parts_dir" &>/dev/null
    fi
  fi
  spinner_stop "Repo synced"

  # --- Discover image sets ---
  # Group chunk files by archive name (strip trailing .NNN numeric suffix).
  # e.g. imageparts/cc-org-api.tar.000 → cc-org-api.tar
  local archives=()
  mapfile -t archives < <(
    find "$parts_dir" -maxdepth 1 -type f -name "*.tar.*" \
      | sed 's/\.[0-9][0-9]*$//' \
      | sort -u \
      | xargs -I{} basename {}
  )
  [[ ${#archives[@]} -gt 0 ]] || die "no image chunks found in imageparts/"

  # --- For each archive: assemble (to repo_dir root) → load → remove ---
  for archive in "${archives[@]}"; do
    local image_tar="$repo_dir/$archive"   # direct child of .bagitops-repo/

    local chunks=()
    mapfile -t chunks < <(find "$parts_dir" -maxdepth 1 -name "${archive}.*" -type f | sort)

    rm -f "$image_tar"
    local i=0
    for chunk in "${chunks[@]}"; do
      (( i++ ))
      cat "$chunk" >> "$image_tar"
      progress_bar "$i" "${#chunks[@]}" "assembling $archive"
    done

    spinner_start "Loading $archive..."
    local load_out
    load_out="$(docker load -i "$image_tar" 2>&1)"
    spinner_stop "$archive loaded"
    printf "  ${DIM}%s${RESET}\n" "$load_out" >&2

    rm -f "$image_tar"
  done

  # --- Promote docker-compose.yml before wiping imageparts/ ---
  local compose_src="$parts_dir/docker-compose.yml"
  [[ -f "$compose_src" ]] || die "docker-compose.yml not found in imageparts/ — incomplete repo?"
  cp "$compose_src" "$repo_dir/docker-compose.yml"
  spinner_stop "docker-compose.yml ready"

  # --- Validate bind-mount conventions ---
  check_bind_mount_paths "$repo_dir/docker-compose.yml"

  # --- Wipe all contents of imageparts/ (.git, chunks, everything) ---
  spinner_start "Clearing imageparts/..."
  find "$parts_dir" -mindepth 1 -delete
  spinner_stop "imageparts/ cleared"

  printf "\n  Run ${BOLD}bagitops run${RESET} to start containers.\n\n" >&2
}
