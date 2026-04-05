#!/usr/bin/env bash
# bagitops update — pull latest from the CLI repo itself

CLI_DIR="$BAGITOPS_CLI_DIR/cli"

cmd_update() {
  require_cmd git

  [[ -d "$CLI_DIR/.git" ]] || die "bagitops CLI repo not found at $CLI_DIR — reinstall via the install script"

  # --- Download ---
  spinner_start "Downloading latest bagitops..."
  local fetch_out
  if ! fetch_out="$(
    GIT_TERMINAL_PROMPT=0 \
    GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15" \
    git -C "$CLI_DIR" fetch origin 2>&1
  )"; then
    spinner_fail "Download failed"
    printf "  ${DIM}%s${RESET}\n" "$fetch_out" >&2
    exit 1
  fi
  spinner_stop "Download complete"

  # --- Check if anything changed ---
  local current_sha remote_sha
  current_sha="$(git -C "$CLI_DIR" rev-parse HEAD)"
  remote_sha="$(git -C "$CLI_DIR" rev-parse FETCH_HEAD)"

  if [[ "$current_sha" == "$remote_sha" ]]; then
    printf "  ${GREEN}✓${RESET}  Already up to date\n" >&2
    return 0
  fi

  # --- Show what changed ---
  printf "  ${DIM}  changed files:${RESET}\n" >&2
  git -C "$CLI_DIR" diff --name-only HEAD FETCH_HEAD | while IFS= read -r f; do
    printf "  ${DIM}    • %s${RESET}\n" "$f" >&2
  done

  # --- Apply ---
  spinner_start "Replacing old files..."
  local merge_out
  if ! merge_out="$(git -C "$CLI_DIR" merge --ff-only FETCH_HEAD 2>&1)"; then
    spinner_fail "Update failed"
    printf "  ${DIM}%s${RESET}\n" "$merge_out" >&2
    exit 1
  fi
  spinner_stop "Files replaced"

  printf "  ${GREEN}✓${RESET}  bagitops updated ${DIM}(%.12s → %.12s)${RESET}\n" "$current_sha" "$remote_sha" >&2
}
