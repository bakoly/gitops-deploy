#!/usr/bin/env bash
# bagitops pull <git-repo-url> [--ssh-key <path>]

cmd_pull() {
  local repo_url="" ssh_key=""

  [[ $# -ge 1 ]] || { bagitops_usage; exit 1; }
  repo_url="$1"; shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ssh-key) ssh_key="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  require_cmd git
  require_cmd docker

  local git_ssh_cmd=""
  if [[ -n "$ssh_key" ]]; then
    [[ -f "$ssh_key" ]] || die "ssh key not found: $ssh_key"
    git_ssh_cmd="ssh -i $ssh_key -o StrictHostKeyChecking=no -o BatchMode=yes"
  fi

  mkdir -p "$REPO_DIR"

  # --- Sync repo ---
  spinner_start "Syncing repo..."
  if [[ -d "$REPO_DIR/.git" ]]; then
    if [[ -n "$git_ssh_cmd" ]]; then
      GIT_SSH_COMMAND="$git_ssh_cmd" git -C "$REPO_DIR" remote set-url origin "$repo_url" &>/dev/null
      GIT_SSH_COMMAND="$git_ssh_cmd" git -C "$REPO_DIR" pull --ff-only &>/dev/null
    else
      git -C "$REPO_DIR" remote set-url origin "$repo_url" &>/dev/null
      git -C "$REPO_DIR" pull --ff-only &>/dev/null
    fi
  else
    rm -rf "$REPO_DIR"
    if [[ -n "$git_ssh_cmd" ]]; then
      GIT_SSH_COMMAND="$git_ssh_cmd" git clone "$repo_url" "$REPO_DIR" &>/dev/null
    else
      git clone "$repo_url" "$REPO_DIR" &>/dev/null
    fi
  fi
  spinner_stop "Repo synced"

  # --- Find chunks ---
  local chunks
  mapfile -t chunks < <(find "$REPO_DIR" -maxdepth 1 -name "image.tar.part.*" | sort)
  [[ ${#chunks[@]} -gt 0 ]] || die "no image chunks found (image.tar.part.*) in repo root"

  # --- Assemble chunks ---
  local tmp_tar
  tmp_tar="$(mktemp /tmp/bagitops_image_XXXXXX.tar)"
  trap 'rm -f "$tmp_tar"' EXIT

  local i=0
  for chunk in "${chunks[@]}"; do
    (( i++ ))
    cat "$chunk" >> "$tmp_tar"
    progress_bar "$i" "${#chunks[@]}" "assembling chunks"
  done

  # --- Load image ---
  spinner_start "Loading image into Docker..."
  local load_out
  load_out="$(docker load -i "$tmp_tar" 2>&1)"
  spinner_stop "Image loaded"
  printf "  ${DIM}%s${RESET}\n" "$load_out" >&2

  # --- Persist config ---
  mkdir -p "$BAGITOPS_DIR"
  cat > "$CONFIG_FILE" <<CONF
BAGITOPS_REPO_URL="$repo_url"
BAGITOPS_SSH_KEY="$ssh_key"
BAGITOPS_REPO_DIR="$REPO_DIR"
CONF

  printf "\n  Run ${BOLD}bagitops run${RESET} to start containers.\n\n" >&2
}
