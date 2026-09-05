#!/usr/bin/env bash
set -euo pipefail

# Append owned blocks without replacing user content. These hooks run both at
# build time and at startup, making repeated starts and supplied home files safe.
devshell_append_block() {
  local devshell_rc=$1 devshell_label=$2 devshell_body=$3
  if ! grep -Fqx "# >>> devshell $devshell_label >>>" "$devshell_rc" 2>/dev/null; then
    printf '\n# >>> devshell %s >>>\n%s\n# <<< devshell %s <<<\n' \
      "$devshell_label" "$devshell_body" "$devshell_label" >> "$devshell_rc"
  fi
}

mkdir -p "$HOME"
devshell_append_block "$HOME/.bashrc" mise 'eval "$(mise activate bash)"
DEVSHELL_BASHRC_PID=$$'
devshell_append_block "$HOME/.zshrc" mise 'eval "$(mise activate zsh)"'
devshell_append_block "$HOME/.zshrc" prompt 'autoload -Uz vcs_info
autoload -Uz add-zsh-hook
add-zsh-hook precmd vcs_info
zstyle '\'':vcs_info:git:*'\'' formats '\''%b '\''
setopt PROMPT_SUBST
PROMPT='\''%F{red}dsh:%f%F{blue}%~%f %F{red}${vcs_info_msg_0_}%f$ '\'''

# Bash reads the first existing login file only. Use that file so a user's
# .bash_login/.profile is not hidden by a newly created .bash_profile.
devshell_profile="$HOME/.bash_profile"
for devshell_candidate in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
  if [[ -f "$devshell_candidate" ]]; then
    devshell_profile=$devshell_candidate
    break
  fi
done
devshell_append_block "$devshell_profile" bash-login 'if [ -n "${BASH_VERSION:-}" ] && [ "${DEVSHELL_BASHRC_PID:-}" != "$$" ]; then
  case $- in *i*) [ ! -r "$HOME/.bashrc" ] || . "$HOME/.bashrc" ;; esac
fi'
