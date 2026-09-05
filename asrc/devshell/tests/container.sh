#!/usr/bin/env bash
set -euo pipefail

devshell_arch=$1
devshell_uid=$2
devshell_gid=$3
test "$(dpkg --print-architecture)" = "$devshell_arch"
test "$(id -u)" = "$devshell_uid"
test "$(id -g)" = "$devshell_gid"
test "$HOME" = "$(getent passwd "$(id -un)" | cut -d: -f6)"
test -w "$HOME"
test -w "$DEVSHELL_BIN"
test -w "$PWD"
test ! -e /work/.proto
test ! -e /work/.prototools

cmp /usr/local/share/devshell/mise/config.toml "$HOME/.config/mise/config.toml"
test "$(stat -c %u "$HOME/.config/mise/config.toml")" = "$devshell_uid"
test "$(stat -c %u "$DEVSHELL_BIN/mise")" = "$devshell_uid"
eget --version
mise --version
for devshell_tool in fzf fd eza yazi rg; do
  "$devshell_tool" --version
  devshell_executable=$(mise which "$devshell_tool")
  case "$devshell_executable" in "$HOME/.local/share/mise/installs/"*) ;; *) exit 1 ;; esac
  test "$(stat -c %u "$devshell_executable")" = "$devshell_uid"
done
for devshell_pkg in fzf fd-find eza yazi ripgrep; do
  test "$(dpkg-query -W -f='${db:Status-Status}' "$devshell_pkg" 2>/dev/null || true)" != installed
done

# Exercise actual binaries through each startup mode, not just shell syntax.
for devshell_shell in bash zsh; do
  "$devshell_shell" -c 'for tool in fzf fd eza yazi rg; do "$tool" --version >/dev/null || exit; done'
  "$devshell_shell" -ic 'for tool in fzf fd eza yazi rg; do "$tool" --version >/dev/null || exit; done'
  "$devshell_shell" -lic 'for tool in fzf fd eza yazi rg; do "$tool" --version >/dev/null || exit; done'
done

# Startup must not erase user files or append duplicate owned blocks.
printf '\n# devshell-test-user-content\n' >> "$HOME/.zshrc"
bash /usr/local/share/devshell/init-shells.sh
bash /usr/local/share/devshell/init-shells.sh
grep -Fqx '# devshell-test-user-content' "$HOME/.zshrc"
test "$(grep -Fxc '# >>> devshell mise >>>' "$HOME/.zshrc")" = 1
test "$(grep -Fxc '# >>> devshell mise >>>' "$HOME/.bashrc")" = 1
test "$(bash /usr/local/share/devshell/entrypoint.sh printf '%s' 'a b')" = 'a b'
if bash /usr/local/share/devshell/entrypoint.sh bash -c 'exit 17'; then
  printf 'Entrypoint swallowed a failing exit code\n' >&2; exit 1
else
  test "$?" = 17
fi
printf 'devshell %s checks passed\n' "$devshell_arch"
