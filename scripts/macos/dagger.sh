#!/usr/bin/env bash
set -euo pipefail
devshell_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$devshell_script_dir/runtime.sh"

if ! command -v dagger >/dev/null 2>&1; then
  printf 'Install the Dagger CLI: https://docs.dagger.io/cli/install/\n' >&2
  exit 1
fi
devshell_require_apple_runtime
devshell_require_apple_engine
cd -- "$devshell_script_dir/../.."

# Select Apple explicitly even when Docker is installed, and make export-image
# use the same image store. Keep the runner and CLI versions in agreement.
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="container+apple://$devshell_engine_name"
export DEVSHELL_APPLE_CONTAINER="$(command -v container)"
export PATH="$devshell_script_dir/compat:$PATH"
# The beta can log an image-loader error but still return success. Preserve
# errors from the compatibility adapter independently of that response.
devshell_export_errors=$(mktemp)
trap 'rm -f -- "$devshell_export_errors"' EXIT
export DEVSHELL_APPLE_EXPORT_ERRORS="$devshell_export_errors"
if [[ $# -eq 0 ]]; then
  set -- --progress=tty api call devshell shell
fi
if dagger --x-release="$devshell_dagger_version" "$@"; then
  if [[ -s "$devshell_export_errors" ]]; then
    cat "$devshell_export_errors" >&2
    exit 1
  fi
else
  exit "$?"
fi
