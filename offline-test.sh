#!/usr/bin/env bash
# Run bagitops from this local repo without installing.
# Usage: ./offline-test.sh <command> [args...]
#   e.g. ./offline-test.sh pull git@github.com:you/app.git --ssh-key ~/.ssh/id_rsa
#        ./offline-test.sh run
#        ./offline-test.sh update

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/bagitops" "$@"
