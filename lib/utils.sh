#!/usr/bin/env bash
# Shared helpers

# CLI installation directory (used by update/uninstall only)
BAGITOPS_CLI_DIR="$HOME/bagitops"

die() { echo "error: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# compose_bind_mounts <compose-file> [service-name]
#
# Prints host paths of bind-mount volumes declared in docker-compose.yml.
# If service-name is given, only that service's volumes are printed.
# Handles short form (- ./host:/ctr) and long form (type: bind / source:).
# Named volumes (no leading ./ / ~) are silently skipped.
# ---------------------------------------------------------------------------
compose_bind_mounts() {
  local compose_file="$1"
  local filter_service="${2:-}"

  awk -v target="$filter_service" '
    /^services:/ { in_services=1; next }
    !in_services { next }

    # Service-level line (2-space indent): track which service we are in
    /^  [^ ]/ {
      svc = $0; gsub(/^  /, "", svc); gsub(/:.*$/, "", svc)
      in_target = (target == "" || svc == target)
      in_vols = 0
      next
    }

    # volumes: key within a service (4-space indent)
    in_target && /^    volumes:/ { in_vols=1; next }

    # Any other 4-space key closes the volumes block
    in_target && /^    [^ -]/ { in_vols=0; next }

    # Short-form volume entry: - HOST:CONTAINER (bind only — host starts with . / ~)
    in_target && in_vols && /^      - [.\/~]/ {
      line = $0
      gsub(/^[[:space:]]*-[[:space:]]*/, "", line)  # strip "- "
      gsub(/:.*$/, "", line)                         # strip ":container..."
      gsub(/[[:space:]]+$/, "", line)
      if (line != "") print line
      next
    }

    # Long-form bind mount source line
    in_target && in_vols && /^[[:space:]]+source:[[:space:]]*[.\/~]/ {
      line = $0
      gsub(/^.*source:[[:space:]]*/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      if (line != "") print line
      next
    }
  ' "$compose_file"
}

# ---------------------------------------------------------------------------
# check_bind_mount_paths <compose-file>
#
# Enforces the convention that all bind-mount host paths must be relative
# (start with ./). Absolute paths (/something) are not allowed — data must
# live inside the project tree under bagitops-repo/.
# Dies if any violation is found, listing each offending service + path.
# Named volumes (no leading / or ./) are silently ignored.
# ---------------------------------------------------------------------------
check_bind_mount_paths() {
  local compose_file="$1"

  local violations=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && violations+=("$line")
  done < <(
    awk '
      /^services:/ { in_services=1; next }
      !in_services { next }

      /^  [^ ]/ {
        svc=$0; gsub(/^  /,"",svc); gsub(/:.*$/,"",svc)
        in_vols=0; next
      }

      /^    volumes:/ { in_vols=1; next }
      in_vols && /^    [^ -]/ { in_vols=0; next }

      # Short form with absolute host path: - /absolute/path:/container
      in_vols && /^      - \// {
        host=$0
        gsub(/^[[:space:]]*-[[:space:]]*/,"",host)
        gsub(/:.*$/,"",host)
        gsub(/[[:space:]]+$/,"",host)
        print "  " svc ": " host
        next
      }

      # Long form with absolute source
      in_vols && /^[[:space:]]+source:[[:space:]]*\// {
        src=$0
        gsub(/^.*source:[[:space:]]*/,"",src)
        gsub(/[[:space:]]+$/,"",src)
        print "  " svc ": " src
        next
      }
    ' "$compose_file"
  )

  if [[ ${#violations[@]} -gt 0 ]]; then
    printf "\n  ${RESET}✗  Non-relative bind mount(s) found in docker-compose.yml:\n" >&2
    for v in "${violations[@]}"; do
      printf "     ${YELLOW}%s${RESET}\n" "$v" >&2
    done
    printf "\n  All bind-mount host paths must start with ./ (relative to the project).\n\n" >&2
    die "docker-compose.yml does not follow bind-mount convention"
  fi
}

require_cmd() { command -v "$1" &>/dev/null || die "'$1' is required but not found"; }

# Walk up from the given directory looking for a bagitops anchor file.
# Prints the project root and returns 0 on success, returns 1 if not found.
_find_project_root() {
  local dir="${1:-$PWD}"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/bagitops.conf" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

load_config() {
  local root
  root="$(_find_project_root "$PWD")" \
    || die "not inside a bagitops project — run 'bagitops init <name> <url>' first"

  # shellcheck source=/dev/null
  source "$root/bagitops.conf"

  BAGITOPS_PROJECT_ROOT="$root"
  BAGITOPS_REPO_DIR="$root/bagitops-repo"
}
