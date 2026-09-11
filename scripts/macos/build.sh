#!/usr/bin/env bash
set -euo pipefail
devshell_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Additional arguments are export-image options, e.g. --name and --arches.
"$devshell_script_dir/dagger.sh" api call devshell export-image "$@"

devshell_image_name=""
devshell_next_is_name=false
for devshell_argument in "$@"; do
  if [[ "$devshell_next_is_name" == true ]]; then
    devshell_image_name=$devshell_argument
    devshell_next_is_name=false
  else
    case "$devshell_argument" in
      --name) devshell_next_is_name=true ;;
      --name=*) devshell_image_name=${devshell_argument#--name=} ;;
    esac
  fi
done
if [[ -z "$devshell_image_name" ]]; then
  devshell_image_name=$("$devshell_script_dir/dagger.sh" --silent api call devshell image-name)
fi
container image inspect "$devshell_image_name" >/dev/null
printf 'Exported %s to Apple\x27s image store.\n' "$devshell_image_name"
