#!/usr/bin/env bash
set -euo pipefail

devshell_arch=$1
shift
case "$devshell_arch" in
  amd64) devshell_mise_arch=x64 ;;
  arm64) devshell_mise_arch=arm64 ;;
  *) printf 'Unsupported architecture: %s\n' "$devshell_arch" >&2; exit 1 ;;
esac

devshell_tmp=$(mktemp -d)
trap 'rm -rf -- "$devshell_tmp"' EXIT

# Select the same Linux architecture for the bootstrap even under emulation.
curl -fsSL https://zyedidia.github.io/eget.sh -o "$devshell_tmp/eget.sh"
(cd "$devshell_tmp" && GETEGET_PLATFORM="linux_$devshell_arch" bash ./eget.sh)
install -m 0755 "$devshell_tmp/eget" "$DEVSHELL_BIN/eget"

# The full suffix excludes musl archives and other compression formats. Restrict
# extraction to mise itself so a future multi-binary archive cannot prompt.
eget jdx/mise --asset "linux-${devshell_mise_arch}.tar.xz" \
  --file 'mise/bin/mise' --to "$DEVSHELL_BIN/mise" </dev/null
mise --version

# Additional inputs are repository identifiers, not arbitrary shell/eget flags.
for devshell_repo in "$@"; do
  if [[ ! "$devshell_repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    printf 'Invalid eget repository: %s\n' "$devshell_repo" >&2
    exit 1
  fi
  eget "$devshell_repo" --to "$DEVSHELL_BIN" </dev/null
done

install -d "$HOME/.config/mise"
install -m 0644 /usr/local/share/devshell/mise/config.toml "$HOME/.config/mise/config.toml"
# This exact config is a reviewed module asset. Trust it explicitly, without
# globally disabling mise's checks for future user/project configurations.
mise trust "$HOME/.config/mise/config.toml"
mise install --yes
mise reshim
