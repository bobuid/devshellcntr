#!/usr/bin/env bash
set -euo pipefail

devshell_arch=$1
devshell_uid=$2
devshell_gid=$3
case "$devshell_arch" in
  amd64) devshell_elf_machine=62 ;;
  arm64) devshell_elf_machine=183 ;;
  *) exit 1 ;;
esac
devshell_check_elf() {
  # ELF e_machine identifies the executable itself, including under emulation.
  test "$(od -An -tu2 -j18 -N2 "$1" | tr -d ' ')" = "$devshell_elf_machine"
}
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
test ! -e "$HOME/.config/mise/mise.lock"
devshell_check_elf "$DEVSHELL_BIN/mise"
devshell_check_elf "$DEVSHELL_BIN/eget"
eget --version
mise --version
for devshell_tool in fzf fd eza yazi rg; do
  "$devshell_tool" --version
  devshell_executable=$(mise which "$devshell_tool")
  case "$devshell_executable" in "$HOME/.local/share/mise/installs/"*) ;; *) exit 1 ;; esac
  test "$(stat -c %u "$devshell_executable")" = "$devshell_uid"
  devshell_check_elf "$devshell_executable"
done
for devshell_pkg in fzf fd-find eza yazi ripgrep; do
  test "$(dpkg-query -W -f='${db:Status-Status}' "$devshell_pkg" 2>/dev/null || true)" != installed
done

# Exercise actual binaries through each startup mode, not just shell syntax.
for devshell_shell in bash zsh; do
  "$devshell_shell" -c 'for tool in fzf fd eza yazi rg; do "$tool" --version >/dev/null || exit; done'
  "$devshell_shell" -lc 'for tool in fzf fd eza yazi rg; do "$tool" --version >/dev/null || exit; done'
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
test "$(grep -Fxc '# >>> devshell prompt >>>' "$HOME/.zshrc")" = 1

# A supplied login file must remain the one Bash reads; initialization should
# neither replace its contents nor create a higher-precedence profile.
devshell_test_home=$(mktemp -d)
trap 'rm -rf -- "$devshell_test_home"' EXIT
printf '# custom login\n' > "$devshell_test_home/.bash_login"
printf '# custom bash\n' > "$devshell_test_home/.bashrc"
HOME="$devshell_test_home" bash /usr/local/share/devshell/init-shells.sh
HOME="$devshell_test_home" bash /usr/local/share/devshell/init-shells.sh
test ! -e "$devshell_test_home/.bash_profile"
grep -Fqx '# custom login' "$devshell_test_home/.bash_login"
grep -Fqx '# custom bash' "$devshell_test_home/.bashrc"
test "$(grep -Fxc '# >>> devshell bash-login >>>' "$devshell_test_home/.bash_login")" = 1

# An ordinary file at the agent path must not be treated as an SSH socket.
touch "$devshell_test_home/not-a-socket"
SSH_AUTH_SOCK="$devshell_test_home/not-a-socket" bash /usr/local/share/devshell/entrypoint.sh true
test "$(bash /usr/local/share/devshell/entrypoint.sh printf '%s' 'a b')" = 'a b'
if bash /usr/local/share/devshell/entrypoint.sh bash -c 'exit 17'; then
  printf 'Entrypoint swallowed a failing exit code\n' >&2; exit 1
else
  test "$?" = 17
fi
printf 'devshell %s checks passed\n' "$devshell_arch"
