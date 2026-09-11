#!/usr/bin/env bash
set -euo pipefail
devshell_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$devshell_script_dir/runtime.sh"
devshell_require_apple_runtime

# Keep the caller's working directory so relative bind mounts work naturally.
# Arguments follow container run: [options] IMAGE [command [args...]].
if [[ $# -eq 0 ]]; then
  set -- "${DEVSHELL_IMAGE_NAME:-devshell}"
fi
devshell_run_options=(--rm --interactive)
if [[ -t 0 && -t 1 ]]; then
  devshell_run_options+=(--tty)
fi
exec container run "${devshell_run_options[@]}" "$@"
