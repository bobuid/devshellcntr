# devshellcntr

A Debian development container built with [Dagger's Dang SDK](https://docs.dagger.io/sdks/dang/).
The module lives in `asrc/devshell`; the root `dagger.toml` registers and configures it.
Use **Dagger `v1.0.0-beta.11`** and a running container runtime. There is no application-source input or Node.js toolchain.

## Build and use

Run these commands from the repository root. `--x-release` selects the pinned CLI and engine:

```sh
dagger --x-release=v1.0.0-beta.11 api call devshell dev-container sync
dagger --x-release=v1.0.0-beta.11 api call devshell run --args='rg,--version' stdout
dagger --x-release=v1.0.0-beta.11 api call devshell run --args='printf,%s,hello world' stdout
dagger --x-release=v1.0.0-beta.11 --progress=tty api call devshell shell
dagger --x-release=v1.0.0-beta.11 --progress=tty api call devshell shell --shell=bash
dagger --x-release=v1.0.0-beta.11 api call devshell export-image
```

| Dang action | CLI action | Result |
| --- | --- | --- |
| `devContainer` | `dev-container` | Configured container for further Dagger operations. |
| `run(args)` | `run --args=...` | Execute an argument array, propagate failure, and return the evaluated container. |
| `shell(shell = "zsh")` | `shell --shell=zsh` | Interactive zsh or bash terminal. |
| `exportImage(name, arches)` | `export-image` | Export to the selected host runtime's image store. |
| `check` | `check` | Verify architecture, tools, ownership, and shell initialization. |

`run` passes arguments directly. Shell expressions require an explicit `bash -c` or `zsh -c` argument array. The CLI represents arrays as CSV; quote the whole option to preserve spaces and use CSV quoting for values containing commas. The image entrypoint also preserves argument boundaries and defaults to zsh when no arguments are supplied.

Shell and export actions execute on every invocation while provisioning stays cached. Dagger terminal actions require its TUI (`--progress=tty`) in an interactive host terminal. Files changed inside a Dagger terminal are session-local. Use an exported image and an explicit bind mount to work on host files.

## Configuration

Edit `[modules.devshell.settings]` in `dagger.toml`. Settings are typed constructor parameters and can also be supplied as per-call overrides before the action.

| Setting | Default |
| --- | --- |
| `baseImage` | `debian:forky-slim` |
| `arch` | `auto` |
| `imageName` | `devshell` |
| `userName`, `userId` | `bob`, `501` |
| `userGroupName`, `userGroupId20` | `bobz`, `20` |
| `workRootPath` | `/work` |
| `workFolderPath` | `<workRootPath>/app` |
| `userHomePath` | `<workFolderPath>/.<userName>` |
| `userBinPath` | `<workRootPath>/bin` |
| `sshAgentPath` | `<userHomePath>/.ssh-agent.socket` |
| `baseAptPackages` | `sudo`, `curl`, `xz-utils`, `bash`, `zsh`, `bat`, `openssh-client`, `ca-certificates` |
| `extraAptPackages` | `[]` |
| `egetPackages` | `[]` (optional GitHub `owner/repository` identifiers) |
| `toolRefresh` | `""` |

The user retains primary GID 20 even if Debian already names that group `dialout`; `bobz` is a supplementary group. Passwordless sudo is available inside the development container. `HOME` is explicitly configured. Empty path settings derive from the other settings above. Keep the apt prerequisites when customizing the base package list; use `extraAptPackages` to add packages.

### Architecture

`auto` follows the **Dagger engine's architecture**. A native local engine on Apple Silicon selects ARM64. A remote engine follows its own architecture, independently of the caller's Mac. Only `amd64` and `arm64` targets are supported.

```sh
dagger --x-release=v1.0.0-beta.11 api call devshell --arch=arm64 dev-container platform
dagger --x-release=v1.0.0-beta.11 api call devshell --arch=amd64 check
dagger --x-release=v1.0.0-beta.11 api call devshell export-image --name=devshell:arm64 --arches=arm64
dagger --x-release=v1.0.0-beta.11 api call devshell export-image --name=devshell:multi --arches=amd64,arm64
```

With no `arches`, export uses the configured architecture. Multiple architectures build separate containers and export them through `platformVariants`. Cross-architecture execution needs emulation provided by the runtime/engine; multi-platform import also needs a host image store that supports manifest lists.

### Tools and shells

Eget is always bootstrapped into the user binary directory. It installs the latest stable [mise release](https://github.com/jdx/mise/releases), selecting the target's Linux glibc archive. Optional `egetPackages` must each have one automatically selectable release asset; ambiguous choices fail instead of prompting.

Mise installs `fzf`, `fd`, `eza`, `yazi`, and `ripgrep` (the `rg` command) through its [registered backends](https://mise.jdx.dev/registry.html). These packages are excluded from both base and extra apt requests, including version/architecture-qualified names. Debian's `bat` package provides `batcat`.

The module asset `asrc/devshell/assets/mise/config.toml` is installed as the configured user at `~/.config/mise/config.toml`:

```toml
[tools]
fzf = "latest"
fd = "latest"
eza = "latest"
yazi = "latest"
ripgrep = "latest"
```

The declarations remain `"latest"`; no tool-version lockfile is generated. To fetch fresh releases after a cached build, change `toolRefresh`, for example:

```sh
dagger --x-release=v1.0.0-beta.11 api call devshell --tool-refresh=2026-09-05 dev-container sync
```

The value can be any string. It invalidates the eget/mise installation stages while retaining apt/account caches. Save it in `dagger.toml` to use the refreshed build for subsequent actions.

Both `.zshrc` and `.bashrc` activate mise; interactive Bash login shells also source `.bashrc`. Managed blocks are idempotent and preserve existing file contents and the zsh prompt. The binary directory and `~/.local/share/mise/shims` are on the image PATH, so direct commands and noninteractive shells can use the tools. See [mise activation](https://mise.jdx.dev/getting-started.html) and [shims](https://mise.jdx.dev/dev-tools/shims.html).

The installed home is part of the image. Mount projects beneath the work directory (for example `/work/app/project`), because mounting over the entire work directory or home hides installed tools and configuration. The entrypoint initializes missing shell files and recognizes forwarded SSH agents only when `SSH_AUTH_SOCK` points to a Unix socket.

## macOS with Apple's container CLI

Install [Apple's `container` CLI](https://github.com/apple/container) and Dagger. The wrappers start the runtime if needed, including its default kernel on first use. They start a reusable Dagger engine and export directly into Apple's image store. They can be called from any directory.

```sh
./scripts/macos/build.sh                         # export configured image (devshell)
./scripts/macos/run.sh                           # interactive zsh in devshell
./scripts/macos/run.sh devshell bash             # interactive Bash
./scripts/macos/run.sh devshell rg --version
./scripts/macos/run.sh devshell printf '%s\n' 'hello world'

./scripts/macos/build.sh --name=devshell:arm64 --arches=arm64

# Bind a project below the preinstalled home, keeping host changes on the host:
./scripts/macos/run.sh --volume "$PWD:/work/app/project" \
  --workdir /work/app/project devshell

# Native container flags can be passed before the image:
./scripts/macos/run.sh --ssh --publish 45070:45070 devshell

# Access any Dagger action with the pinned Apple engine:
./scripts/macos/dagger.sh api call devshell check
./scripts/macos/dagger.sh api call devshell --tool-refresh=2026-09-05 export-image
./scripts/macos/dagger.sh --progress=tty api call devshell shell --shell=bash
```

`build.sh` accepts `export-image` options. `run.sh` accepts `[container run options] IMAGE [command [args...]]`; no arguments selects `DEVSHELL_IMAGE_NAME` or `devshell`. When changing `imageName` in TOML or exporting another tag, pass that image to `run.sh`. It keeps stdin open, allocates a TTY only when attached to a terminal, and removes the temporary container on exit. Bind mounts persist host changes; other session changes are discarded. Adjust mount destinations when customizing the work/home paths.

`dagger.sh` pins the Apple runtime even when Docker is also installed; with no arguments it opens the Dagger zsh action. Normal `dagger` commands remain available for other runtimes. Apple's runtime defaults to its native architecture; use `--arch=amd64` for an AMD64 image on Apple Silicon. See [Dagger's Apple runtime support](https://docs.dagger.io/0.21/reference/container-runtimes/apple-container/).

**Tested limitation:** with Apple container 1.3.1 on Apple Silicon and this pinned Dagger engine, building AMD64 fails when eget 1.3.4 crashes in Go's network poller under emulation. Enabling Rosetta for the engine did not resolve it. Native ARM64 builds work. The module's AMD64 build and multi-platform export passed with a Docker-backed engine; use that engine for AMD64 or multi-platform builds until the Apple-hosted emulation issue is resolved. `build.sh` still forwards `--arches`, but AMD64 is not a working Apple build path in this tested combination.

The wrapper manages `devshell-dagger-engine-v1.0.0-beta.11` with 4 CPUs and 8 GiB RAM. It grants the engine capabilities and writable kernel paths inside its Linux VM because beta.11's automatic Apple launcher otherwise fails to enable IP forwarding. The exported development image uses ordinary container permissions. Stop the idle engine with `container stop devshell-dagger-engine-v1.0.0-beta.11`; the next wrapper invocation starts it again. Removing that engine container also discards its build cache.

The scripts also adapt beta.11's bare-digest tagging call to Apple container 1.3's full image-reference format. This adapter applies only to Dagger's child processes and propagates loader errors that the beta otherwise only logs. The module handles the beta's empty export-response decoding issue; `build.sh` verifies the requested image exists in Apple's image store before declaring export complete.

## Optional Docker Compose

Export with Dagger connected to Docker, then run the existing Compose consumer:

```sh
dagger --x-release=v1.0.0-beta.11 api call devshell export-image
docker run --rm devshell rg --version
docker compose -f config/devshell/default.compose.yml run --rm xox-host
# Optional port/host-network overlay:
docker compose -f config/devshell/default.compose.yml \
  -f config/devshell/default-net.compose.yml run --rm --service-ports xox-host
```

Set `DEVSHELL_IMAGE_NAME` to consume another exported tag. Compose does not build the image. The `_-dev` directory is excluded from this migration.

## Validation

```sh
dagger --x-release=v1.0.0-beta.11 api call devshell check
dagger --x-release=v1.0.0-beta.11 api call devshell --arch=amd64 check
dagger --x-release=v1.0.0-beta.11 api call devshell --arch=arm64 check
```

The checks execute all five tools directly and through noninteractive, interactive, and login Bash/zsh; verify ELF and Debian architecture, ownership and the unchanged mise config; exclude apt duplicates; and test argument boundaries, failures, and repeated shell initialization. Runtime checks require a running container engine.

`bash asrc/devshell/tests/macos.sh` checks wrapper arguments, paths containing spaces, image tagging compatibility, and failure propagation with a mock runtime. It does not start containers. The generated `dagger.lock` records Dagger's base-image resolution; mise's tool configuration remains unlocked and uses `"latest"`.

Executed validation: both architecture checks, Docker execution, and single/multi-platform Docker exports passed on 2026-09-05. On 2026-09-11, native ARM64 Apple checks, repeated image export, commands with spaces, exit-code propagation, interactive Dagger Bash, and the exported image's default zsh passed. The macOS wrapper checks also passed under macOS Bash 3.2. Apple-hosted AMD64 builds remain subject to the limitation above.
