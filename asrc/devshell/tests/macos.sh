#!/usr/bin/env bash
# Exercise wrapper argument forwarding without starting either runtime.
set -euo pipefail
devshell_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
devshell_test_tmp=$(mktemp -d)
trap 'rm -rf -- "$devshell_test_tmp"' EXIT
mkdir -p "$devshell_test_tmp/bin" "$devshell_test_tmp/project with spaces"
export DEVSHELL_TEST_CAPTURE="$devshell_test_tmp/argv"
export DEVSHELL_TEST_CWD="$devshell_test_tmp/cwd"
export DEVSHELL_TEST_RUNNER="$devshell_test_tmp/runner"
export DEVSHELL_TEST_ENGINE_ARGS="$devshell_test_tmp/engine-args"
export DEVSHELL_TEST_IMAGE_INSPECT="$devshell_test_tmp/image-inspect"

cat > "$devshell_test_tmp/bin/container" <<'MOCK'
#!/bin/bash
if [[ "$1 $2" == 'system status' ]]; then exit 0; fi
if [[ "$1 $2" == 'ls --quiet' ]]; then exit 0; fi
if [[ "$1" == inspect ]]; then exit 1; fi
if [[ "$1 $2" == 'image inspect' ]]; then
  printf '%s\n' "$3" > "$DEVSHELL_TEST_IMAGE_INSPECT"
  exit 0
fi
if [[ "$1 $2" == 'run --detach' ]]; then
  printf '%s\n' "$@" > "$DEVSHELL_TEST_ENGINE_ARGS"
  exit 0
fi
printf '%s\n' "$@" > "$DEVSHELL_TEST_CAPTURE"
pwd > "$DEVSHELL_TEST_CWD"
exit "${DEVSHELL_TEST_EXIT:-0}"
MOCK
cat > "$devshell_test_tmp/bin/dagger" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" > "$DEVSHELL_TEST_CAPTURE"
pwd > "$DEVSHELL_TEST_CWD"
printf '%s\n' "$_EXPERIMENTAL_DAGGER_RUNNER_HOST" > "$DEVSHELL_TEST_RUNNER"
if [[ "${*: -1}" == image-name ]]; then printf 'devshell:configured\n'; fi
if [[ "${DEVSHELL_TEST_EXPORT_ERROR:-}" == 1 ]]; then
  container image tag aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa devshell:test
  exit 0 # Mimic the beta losing the loader's exit status.
fi
MOCK
cat > "$devshell_test_tmp/bin/uname" <<'MOCK'
#!/bin/bash
printf 'Darwin\n'
MOCK
chmod +x "$devshell_test_tmp/bin/"*
export PATH="$devshell_test_tmp/bin:$PATH"
cd "$devshell_test_tmp/project with spaces"

"$devshell_repo/scripts/macos/build.sh" --name=devshell:test --arches=amd64,arm64
printf '%s\n' --x-release=v1.0.0-beta.11 api call devshell export-image \
  --name=devshell:test --arches=amd64,arm64 > "$devshell_test_tmp/expected"
cmp "$DEVSHELL_TEST_CAPTURE" "$devshell_test_tmp/expected"
test "$(cat "$DEVSHELL_TEST_CWD")" = "$devshell_repo"
test "$(cat "$DEVSHELL_TEST_RUNNER")" = container+apple://devshell-dagger-engine-v1.0.0-beta.11
printf '%s\n' run --detach --name devshell-dagger-engine-v1.0.0-beta.11 \
  --cap-add ALL --read-only-path NONE --masked-path NONE --cpus 4 --memory 8G \
  registry.dagger.io/engine:v1.0.0-beta.11 > "$devshell_test_tmp/expected"
cmp "$DEVSHELL_TEST_ENGINE_ARGS" "$devshell_test_tmp/expected"
test "$(cat "$DEVSHELL_TEST_IMAGE_INSPECT")" = devshell:test

"$devshell_repo/scripts/macos/build.sh"
test "$(cat "$DEVSHELL_TEST_IMAGE_INSPECT")" = devshell:configured

if DEVSHELL_TEST_EXPORT_ERROR=1 DEVSHELL_TEST_EXIT=17 \
  "$devshell_repo/scripts/macos/dagger.sh" api call devshell export-image > "$devshell_test_tmp/export-error" 2>&1; then
  printf 'The wrapper swallowed an image-loader failure\n' >&2; exit 1
else
  test "$?" = 1
fi
grep -Fq 'Apple image tag failed (exit 17)' "$devshell_test_tmp/export-error"

# The adapter is local to Dagger and only repairs its legacy digest tag call.
export DEVSHELL_APPLE_CONTAINER="$devshell_test_tmp/bin/container"
devshell_digest=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
"$devshell_repo/scripts/macos/compat/container" image tag "$devshell_digest" devshell:test
printf '%s\n' image tag "untagged@sha256:$devshell_digest" devshell:test > "$devshell_test_tmp/expected"
cmp "$DEVSHELL_TEST_CAPTURE" "$devshell_test_tmp/expected"
"$devshell_repo/scripts/macos/compat/container" image tag devshell:test devshell:other
printf '%s\n' image tag devshell:test devshell:other > "$devshell_test_tmp/expected"
cmp "$DEVSHELL_TEST_CAPTURE" "$devshell_test_tmp/expected"

"$devshell_repo/scripts/macos/run.sh" --volume "$PWD:/work/app/project" devshell printf '%s' 'a b,$HOME'
printf '%s\n' run --rm --interactive --volume "$PWD:/work/app/project" \
  devshell printf '%s' 'a b,$HOME' > "$devshell_test_tmp/expected"
cmp "$DEVSHELL_TEST_CAPTURE" "$devshell_test_tmp/expected"
test "$(cat "$DEVSHELL_TEST_CWD")" = "$PWD"

DEVSHELL_IMAGE_NAME=devshell:custom "$devshell_repo/scripts/macos/run.sh"
printf '%s\n' run --rm --interactive devshell:custom > "$devshell_test_tmp/expected"
cmp "$DEVSHELL_TEST_CAPTURE" "$devshell_test_tmp/expected"
if DEVSHELL_TEST_EXIT=17 "$devshell_repo/scripts/macos/run.sh" devshell false; then
  exit 1
else
  test "$?" = 17
fi
printf 'macOS wrapper checks passed\n'
