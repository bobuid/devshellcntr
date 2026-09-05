#!/usr/bin/env bash
set -euo pipefail

bash /usr/local/share/devshell/init-shells.sh
# Only touch an explicitly mounted agent socket, never a regular file. The
# existing dev-shell policy allows the user to repair socket ownership via sudo.
if [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]]; then
  sudo -n chown "$(id -u)" -- "$SSH_AUTH_SOCK"
fi

if [[ $# -eq 0 ]]; then
  set -- zsh
fi
# Preserve argument boundaries and signals; do not evaluate user argv as code.
exec "$@"
