#!/usr/bin/env bash
set -euo pipefail

devshell_user=$1
devshell_uid=$2
devshell_group=$3
devshell_gid=$4
devshell_root=$5
devshell_work=$6
devshell_home=$7
devshell_bin=$8

# Paths are data passed as argv, never interpolated into executable shell text.
# Reject root/dot traversal before creating or changing ownership of directories.
for devshell_path in "$devshell_root" "$devshell_work" "$devshell_home" "$devshell_bin"; do
  case "$devshell_path" in
    /|*/../*|*/..|*/./*|*/.|*$'\n'*|*$'\r'*)
      printf 'Invalid container path: %s\n' "$devshell_path" >&2; exit 1 ;;
    /*) ;;
    *) printf 'Container paths must be absolute: %s\n' "$devshell_path" >&2; exit 1 ;;
  esac
done

# Debian may already own GID 20 (dialout). Preserve the original primary GID
# without renaming a system group; bobz remains the named supplementary group.
if ! getent group "$devshell_gid" >/dev/null; then
  groupadd --gid "$devshell_gid" "$devshell_group"
fi
if ! getent group "$devshell_group" >/dev/null; then
  groupadd "$devshell_group"
fi
useradd --uid "$devshell_uid" --gid "$devshell_gid" \
  --groups "sudo,$devshell_group" --home-dir "$devshell_home" \
  --create-home --shell /usr/bin/zsh "$devshell_user"
install -d -o "$devshell_user" -g "$devshell_group" -- "$devshell_work" "$devshell_home" "$devshell_bin"

# Passwordless sudo is retained intentionally for this development image.
# It grants root within the container; no privileged Dagger/host access is enabled.
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$devshell_user" > /etc/sudoers.d/devshell
chmod 0440 /etc/sudoers.d/devshell
visudo -cf /etc/sudoers.d/devshell
