#!/usr/bin/env bash
# bagitops init [<project-name> <repo-url> [--ssh-key [<path>]]]

_read_ssh_key_paste() {
  local dest="$1"
  printf "  Paste your private SSH key. Enter a blank line when done:\n" >&2
  local key_content="" line
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    key_content+="$line"$'\n'
  done
  [[ -n "$key_content" ]] || die "no key content provided"
  printf '%s' "$key_content" > "$dest"
  chmod 600 "$dest"
}

cmd_init() {
  local project_name="" repo_url="" ssh_key_src=""

  # Refuse to reinit or nest: check current and every parent directory for an existing bagitops anchor
  local check="$PWD"
  while [[ "$check" != "/" ]]; do
    if [[ -f "$check/bagitops.conf" ]]; then
      if [[ "$check" == "$PWD" ]]; then
        die "already initialized in this directory — run 'bagitops pull' to fetch the app"
      else
        die "already inside a bagitops project rooted at '$check' — nesting is not allowed"
      fi
    fi
    check="$(dirname "$check")"
  done

  # ---------------------------------------------------------------------------
  # Interactive wizard when no arguments are given
  # ---------------------------------------------------------------------------
  if [[ $# -eq 0 ]]; then
    printf "\n  ${BOLD}bagitops init${RESET} — project setup\n\n" >&2

    printf "  Project name: " >&2
    read -r project_name
    [[ -n "$project_name" ]] || die "project name cannot be empty"

    printf "  Repo URL:     " >&2
    read -r repo_url
    [[ -n "$repo_url" ]] || die "repo URL cannot be empty"

    printf "  Use an SSH key? [y/N] " >&2
    local yn; read -r yn
    if [[ "$yn" =~ ^[Yy] ]]; then
      printf "  Key path (leave blank to paste): " >&2
      local key_path; read -r key_path
      ssh_key_src="${key_path:-__paste__}"
    fi

  # ---------------------------------------------------------------------------
  # Non-interactive: bagitops init <name> <url> [--ssh-key [<path>]]
  # ---------------------------------------------------------------------------
  else
    [[ $# -ge 2 ]] || { printf "Usage: bagitops init <project-name> <repo-url> [--ssh-key [<path>]]\n" >&2; exit 1; }
    project_name="$1"; shift
    repo_url="$1"; shift

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --ssh-key)
          if [[ $# -gt 1 && "$2" != --* ]]; then
            ssh_key_src="$2"; shift 2
          else
            ssh_key_src="__paste__"; shift
          fi
          ;;
        *) die "unknown option: $1" ;;
      esac
    done
  fi

  # Validate URL
  [[ "$repo_url" =~ ^(https?://|git@|ssh://) ]] \
    || die "repo URL must start with https://, http://, git@, or ssh://"

  # Validate SSH key path if provided in copy mode
  if [[ -n "$ssh_key_src" && "$ssh_key_src" != "__paste__" ]]; then
    [[ -f "$ssh_key_src" ]] || die "ssh key not found: $ssh_key_src"
  fi

  # Create project directories
  mkdir -p "$PWD/bagitops-repo"
  mkdir -p "$PWD/envs"
  mkdir -p "$PWD/data"

  # Copy or paste the SSH key into the project folder
  local ssh_key=""
  if [[ -n "$ssh_key_src" ]]; then
    local key_dest="$PWD/bagitops-repo/bagitops_key"
    if [[ "$ssh_key_src" == "__paste__" ]]; then
      _read_ssh_key_paste "$key_dest"
    else
      cp "$ssh_key_src" "$key_dest"
      chmod 600 "$key_dest"
    fi
    ssh_key="$key_dest"
  fi

  # Write the anchor + config into the current directory
  cat > "$PWD/bagitops.conf" <<CONF
BAGITOPS_PROJECT_NAME="$project_name"
BAGITOPS_REPO_URL="$repo_url"
BAGITOPS_SSH_KEY="$ssh_key"
CONF

  printf "\n" >&2
  printf "  ${GREEN}✓${RESET}  Project: ${BOLD}%s${RESET}\n" "$project_name" >&2
  printf "  ${GREEN}✓${RESET}  Repo:    ${DIM}%s${RESET}\n" "$repo_url" >&2
  printf "  ${GREEN}✓${RESET}  Created: ${DIM}bagitops-repo/  envs/  data/${RESET}\n" >&2
  if [[ -n "$ssh_key" ]]; then
    printf "  ${GREEN}✓${RESET}  SSH key: ${DIM}stored in project folder${RESET}\n" >&2
  else
    printf "  ${DIM}      No SSH key — repo will be accessed over HTTPS${RESET}\n" >&2
  fi

  printf "\n  Run ${BOLD}bagitops pull${RESET} to fetch the app.\n\n" >&2
}
