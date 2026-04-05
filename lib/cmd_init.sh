#!/usr/bin/env bash
# bagitops init <project-name> <repo-url> [--ssh-key <path>]

cmd_init() {
  local project_name="" repo_url="" ssh_key=""

  [[ $# -ge 2 ]] || { printf "Usage: bagitops init <project-name> <repo-url> [--ssh-key <path>]\n" >&2; exit 1; }
  project_name="$1"; shift
  repo_url="$1"; shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ssh-key) ssh_key="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  # Validate URL
  [[ "$repo_url" =~ ^(https?://|git@|ssh://) ]] \
    || die "repo URL must start with https://, http://, git@, or ssh://"

  # Validate SSH key if provided
  if [[ -n "$ssh_key" ]]; then
    [[ -f "$ssh_key" ]] || die "ssh key not found: $ssh_key"
    ssh_key="$(realpath "$ssh_key")"
  fi

  # Refuse to nest: check every parent directory for an existing .bagitops anchor
  local parent
  parent="$(dirname "$PWD")"
  local check="$parent"
  while [[ "$check" != "/" ]]; do
    if [[ -f "$check/.bagitops" ]]; then
      die "already inside a bagitops project rooted at '$check' — nesting is not allowed"
    fi
    check="$(dirname "$check")"
  done

  # Write the anchor + config into the current directory
  cat > "$PWD/.bagitops" <<CONF
BAGITOPS_PROJECT_NAME="$project_name"
BAGITOPS_REPO_URL="$repo_url"
BAGITOPS_SSH_KEY="$ssh_key"
CONF

  printf "  ${GREEN}✓${RESET}  Project: ${BOLD}%s${RESET}\n" "$project_name" >&2
  printf "  ${GREEN}✓${RESET}  Repo:    ${DIM}%s${RESET}\n" "$repo_url" >&2
  if [[ -n "$ssh_key" ]]; then
    printf "  ${GREEN}✓${RESET}  SSH key: ${DIM}%s${RESET}\n" "$ssh_key" >&2
  else
    printf "  ${DIM}      No SSH key — repo will be accessed over HTTPS${RESET}\n" >&2
  fi

  printf "\n  Run ${BOLD}bagitops pull${RESET} to fetch the app.\n\n" >&2
}
