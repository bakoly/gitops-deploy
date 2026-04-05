#!/usr/bin/env bash
set -euo pipefail

CLI_REPO="https://github.com/bakoly/gitops-deploy.git"
CLI_DIR="$HOME/bagitops/cli"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="bagitops"

die() { echo "error: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' is required but not installed"
}

echo "==> Installing bagitops..."

require_cmd curl
require_cmd git
require_cmd docker

# Clone or update the CLI repo
mkdir -p "$HOME/bagitops"
if [[ -d "$CLI_DIR/.git" ]]; then
  echo "==> Updating existing CLI repo..."
  git -C "$CLI_DIR" pull --ff-only
else
  echo "==> Cloning CLI repo..."
  git clone "$CLI_REPO" "$CLI_DIR"
fi

chmod +x "$CLI_DIR/$SCRIPT_NAME"

# Install a launcher into PATH
if [[ -w "$INSTALL_DIR" ]]; then
  SUDO=""
else
  command -v sudo &>/dev/null || die "cannot write to $INSTALL_DIR and 'sudo' is not available"
  SUDO="sudo"
fi

$SUDO tee "$INSTALL_DIR/$SCRIPT_NAME" > /dev/null <<LAUNCHER
#!/usr/bin/env bash
exec "$CLI_DIR/$SCRIPT_NAME" "\$@"
LAUNCHER
$SUDO chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "==> bagitops installed to $INSTALL_DIR/$SCRIPT_NAME"
echo ""
echo "Usage:"
echo "  bagitops pull <git-repo-url> [--ssh-key <path>]"
echo "  bagitops run"
echo "  bagitops update"
