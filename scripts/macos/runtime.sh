#!/usr/bin/env bash
# Shared by the executable wrappers; compatible with macOS's Bash 3.2.
set -euo pipefail
devshell_dagger_version=v1.0.0-beta.11
devshell_engine_name="devshell-dagger-engine-$devshell_dagger_version"

devshell_require_apple_runtime() {
  if [[ "$(uname -s)" != Darwin ]]; then
    printf 'These scripts require macOS and Apple\x27s container CLI.\n' >&2
    exit 1
  fi
  if ! command -v container >/dev/null 2>&1; then
    printf 'Install Apple\x27s container CLI: https://github.com/apple/container\n' >&2
    exit 1
  fi
  if ! container system status >/dev/null 2>&1; then
    container system start --enable-kernel-install
  fi
}

devshell_require_apple_engine() {
  if container ls --quiet | grep -Fxq "$devshell_engine_name"; then
    return
  fi
  if container inspect "$devshell_engine_name" >/dev/null 2>&1; then
    container start "$devshell_engine_name" >/dev/null
  else
    # beta.11's automatic Apple launcher leaves /proc/sys read-only. The
    # engine needs writable kernel settings for CNI inside its Linux VM.
    # These privileges belong to the build engine, not the devshell image.
    container run --detach --name "$devshell_engine_name" \
      --cap-add ALL --read-only-path NONE --masked-path NONE \
      --cpus 4 --memory 8G "registry.dagger.io/engine:$devshell_dagger_version" >/dev/null
  fi
}
