#!/usr/bin/env bash
# UI helpers: banner, spinner, progress bar

# Colors (disabled when not a TTY)
if [[ -t 2 ]]; then
  RESET='\033[0m'
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  DIM='\033[2m'
else
  RESET='' BOLD='' GREEN='' YELLOW='' CYAN='' DIM=''
fi

print_banner() {
  printf "${CYAN}${BOLD}" >&2
  printf '  ╔══════════════════════════╗\n' >&2
  printf '  ║     b a g i t o p s      ║\n' >&2
  printf '  ║   gitops deploy util     ║\n' >&2
  printf '  ╚══════════════════════════╝\n' >&2
  printf "${RESET}\n" >&2
}

# ---------------------------------------------------------------------------
# Spinner
# ---------------------------------------------------------------------------
_SPINNER_PID=""

spinner_start() {
  local msg="$1"
  [[ -t 2 ]] || { printf "  ... %s\n" "$msg" >&2; return; }
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  (
    trap '' INT TERM
    while true; do
      for f in "${frames[@]}"; do
        printf "\r  ${CYAN}%s${RESET}  %s" "$f" "$msg" >&2
        sleep 0.08
      done
    done
  ) &
  _SPINNER_PID=$!
}

spinner_stop() {
  local msg="$1"
  if [[ -n "$_SPINNER_PID" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
  fi
  printf "\r  ${GREEN}✓${RESET}  %s\n" "$msg" >&2
}

spinner_fail() {
  local msg="$1"
  if [[ -n "$_SPINNER_PID" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
  fi
  printf "\r  ${RESET}✗  %s\n" "$msg" >&2
}

# Ensure spinner is killed if the script exits unexpectedly
trap 'spinner_fail "aborted"; exit 130' INT TERM

# ---------------------------------------------------------------------------
# Progress bar
# Usage: progress_bar <current> <total> <label>
# ---------------------------------------------------------------------------
progress_bar() {
  local current=$1 total=$2 label="$3"
  local width=26
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar="" i
  for (( i=0; i<filled; i++ )); do bar+="█"; done
  for (( i=0; i<empty;  i++ )); do bar+="░"; done
  printf "\r  ${CYAN}[%s]${RESET}  %d/%d  %s" "$bar" "$current" "$total" "$label" >&2
  if [[ "$current" -eq "$total" ]]; then
    printf "\n" >&2
    printf "  ${GREEN}✓${RESET}  %s\n" "$label done" >&2
  fi
}
