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
      # Offer to create the file interactively (finish input with Ctrl-D)
      read -r -p "  Create and enter content for '$src' now? Finish with Ctrl-D (y/N): " ans
      case "$ans" in
        [Yy]*)
          printf "  Enter content, finish with Ctrl-D:\n"
          cat > "$src"
          if [[ ! -f "$src" ]]; then
            printf "  ${RESET}✗  failed to create: %s\n" "$src" >&2
            any_error=1
            continue
          fi
          ;;
        *)
          any_error=1
          continue
          ;;
      esac
    fi
    local name
    name="$(basename "$src")"
    cp "$src" "$target_dir/$name"
    printf "  ${GREEN}✓${RESET}  %s  ${DIM}→ %s${RESET}\n" "$name" "$target_dir/$name" >&2
  done

  [[ $any_error -eq 0 ]] || die "one or more env files could not be copied"

  printf "\n  Run ${BOLD}bagitops run${RESET} to start containers.\n\n" >&2
}
