#!/usr/bin/env bash
# bagitops setenv <env-file> [<env-file> ...]

cmd_setenv() {
  [[ $# -ge 1 ]] || { printf "Usage: bagitops setenv <env-file> [<env-file> ...]\n" >&2; exit 1; }

  load_config

  local target_dir="$BAGITOPS_REPO_DIR/envs"
  mkdir -p "$target_dir"

  local any_error=0
  for src in "$@"; do
    if [[ ! -f "$src" ]]; then
      printf "  ${RESET}✗  not found: %s\n" "$src" >&2
      any_error=1
      continue
    fi
    local name
    name="$(basename "$src")"
    cp "$src" "$target_dir/$name"
    printf "  ${GREEN}✓${RESET}  %s  ${DIM}→ %s${RESET}\n" "$name" "$target_dir/$name" >&2
  done

  [[ $any_error -eq 0 ]] || die "one or more env files could not be copied"

  printf "\n  Run ${BOLD}bagitops run${RESET} to start containers.\n\n" >&2
}
