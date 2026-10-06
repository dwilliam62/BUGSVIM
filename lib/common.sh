#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Shared Installer Library
# ================================================================================================
# This file provides common utilities, CLI parsing, backup, npm management,
# and verification routines used by all bugsvim install scripts.
# ================================================================================================

# Strict mode
set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Error tracking arrays
FAILED_PACKAGES=()
FAILED_NPM=()
FAILED_PYTHON=()
FAILED_BUILD=()
FAILED_AUR=()
MISSING=0

# Operation flags
FORCE_REINSTALL=0
UPDATE_ONLY=0
DEPS_ONLY=0
CONFIG_UPDATE=0
DEBUG=0
SPECIFIED_DISTRO=""

# Set once a ~/.config/nvim backup has been taken this run (see
# backup_config_dir_if_needed), so --update-config never backs up twice.
BACKUP_DONE=0

# Supported distribution map
SUPPORTED_DISTROS=(
  "arch:Arch Linux, EndeavourOS, Manjaro, CachyOS, Artix, Garuda"
  "debian:Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin OS, Elementary OS, Kali"
  "fedora:Fedora, Nobara, RHEL, CentOS Stream, AlmaLinux, Rocky Linux"
  "gentoo:Gentoo Linux, Funtoo"
  "opensuse:openSUSE Tumbleweed, Leap, SUSE Linux Enterprise"
  "alpine:Alpine Linux"
  "bazzite:Bazzite, Fedora Silverblue/Kinoite, Universal Blue"
  "freebsd:FreeBSD"
  "openbsd:OpenBSD"
  "netbsd:NetBSD"
)

# ================================================================================================
# Logging and Debug Helpers
# ================================================================================================

log_debug() {
  if [ "$DEBUG" -eq 1 ]; then
    echo -e "${MAGENTA}[DEBUG]${NC} $*" >&2
  fi
}

log_info() {
  echo -e "${BLUE}$*${NC}"
}

log_success() {
  echo -e "${GREEN}$*${NC}"
}

log_warn() {
  echo -e "${YELLOW}$*${NC}"
}

log_error() {
  echo -e "${RED}$*${NC}"
}

# ================================================================================================
# Privilege Helper
# ================================================================================================

run_as_root() {
  log_debug "Executing privileged command: $*"
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
    return
  fi

  # 'doas' is not always configured for passwordless use (FreeBSD ships
  # 'permit persist :wheel', which still needs the first password), so pick a
  # tool that actually works without prompting instead of assuming an order.
  if [ -z "${ROOT_CMD:-}" ]; then
    if command -v doas >/dev/null 2>&1 && doas -n true >/dev/null 2>&1; then
      ROOT_CMD="doas"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      ROOT_CMD="sudo"
    elif command -v doas >/dev/null 2>&1; then
      ROOT_CMD="doas"
    elif command -v sudo >/dev/null 2>&1; then
      ROOT_CMD="sudo"
    else
      log_error "Error: Root privileges required via 'sudo' or 'doas'."
      exit 1
    fi
    log_debug "Using '${ROOT_CMD}' for privileged commands"
  fi

  "$ROOT_CMD" "$@"
}

# ================================================================================================
# Resilient Package Installation
# ================================================================================================
# Most package managers resolve every argument before installing anything, so a
# single unavailable name aborts the whole transaction and *nothing* is
# installed (verified for apt, dnf, zypper, pacman, apk and emerge). Install the
# batch first, then retry one package at a time so the resolvable packages still
# land and only the genuinely unavailable names are reported.
#
# Usage: install_packages_resilient "<install command>" pkg1 [pkg2 ...]
install_packages_resilient() {
  local install_cmd="$1"
  shift

  local pkgs=("$@")
  if [ ${#pkgs[@]} -eq 0 ]; then
    return 0
  fi

  log_debug "Batch install: ${install_cmd} ${pkgs[*]}"
  # shellcheck disable=SC2086 # the command prefix is intentionally word-split
  if $install_cmd "${pkgs[@]}"; then
    return 0
  fi

  log_warn "⚠ Batch install failed; retrying packages individually so one unavailable name cannot block the rest..."
  local failed=()
  for pkg in "${pkgs[@]}"; do
    local out
    # shellcheck disable=SC2086
    if out="$($install_cmd "$pkg" 2>&1)"; then
      log_success "✓ $pkg"
    else
      # Some managers (pkgin, pkg_add) return non-zero for unrelated package
      # errors, so show what they actually said instead of guessing.
      local reason
      reason="$(printf '%s\n' "$out" | sed -e 's/^[[:space:]]*//' -e '/^$/d' | tail -1 | cut -c1-140)"
      if [ -n "$reason" ]; then
        log_warn "○ $pkg (failed: ${reason})"
      else
        log_warn "○ $pkg (failed)"
      fi
      failed+=("$pkg")
    fi
  done

  if [ ${#failed[@]} -gt 0 ]; then
    FAILED_PACKAGES+=("${failed[@]}")
    return 1
  fi
  return 0
}

# ================================================================================================
# Lua Language Server (release tarball fallback)
# ================================================================================================
# Debian/Ubuntu do not package lua-language-server, so fall back to the official
# GitHub release tarball: extracted under ~/.local/lua-language-server with a
# wrapper in ~/.local/bin.
install_lua_language_server_from_release() {
  if command -v lua-language-server >/dev/null 2>&1; then
    log_success "✓ lua-language-server already installed"
    return 0
  fi

  local arch
  case "$(uname -m)" in
  x86_64 | amd64) arch="x64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *)
    log_warn "⚠ Unsupported architecture for the lua-language-server release: $(uname -m)"
    FAILED_BUILD+=("lua-language-server")
    return 1
    ;;
  esac

  local tag
  tag="$(curl -fsSL --max-time 30 https://api.github.com/repos/LuaLS/lua-language-server/releases/latest 2>/dev/null |
    sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  if [ -z "$tag" ]; then
    log_warn "⚠ Unable to determine the latest lua-language-server release"
    FAILED_BUILD+=("lua-language-server")
    return 1
  fi

  local dest="${HOME}/.local/lua-language-server"
  local url="https://github.com/LuaLS/lua-language-server/releases/download/${tag}/lua-language-server-${tag}-linux-${arch}.tar.gz"

  log_info "Installing lua-language-server ${tag} (${arch}) to ${dest}..."
  mkdir -p "$dest" "${HOME}/.local/bin"
  if curl -fsSL --max-time 300 "$url" | tar -xz -C "$dest"; then
    # The launcher resolves main.lua relative to its own location, so wrap it
    # rather than symlinking from ~/.local/bin.
    cat >"${HOME}/.local/bin/lua-language-server" <<EOF
#!/bin/sh
exec "${dest}/bin/lua-language-server" "\$@"
EOF
    chmod +x "${HOME}/.local/bin/lua-language-server"
    export PATH="${HOME}/.local/bin:$PATH"
    log_success "✓ lua-language-server ${tag} installed to ${HOME}/.local/bin"
  else
    log_warn "⚠ lua-language-server download failed: $url"
    FAILED_BUILD+=("lua-language-server")
    return 1
  fi
}

# ================================================================================================
# CLI Argument Parsing & Help
# ================================================================================================

list_supported_distros() {
  echo -e "${BLUE}Supported Distributions for bugsvim:${NC}"
  echo ""
  printf "  %-12s  %s\n" "KEY" "MATCHED DISTRIBUTIONS / DERIVATIVES"
  printf "  %-12s  %s\n" "---" "------------------------------------"
  for entry in "${SUPPORTED_DISTROS[@]}"; do
    local key="${entry%%:*}"
    local desc="${entry#*:}"
    printf "  ${GREEN}%-12s${NC}  %s\n" "$key" "$desc"
  done
  echo ""
  echo -e "You can pass ${CYAN}--distro <key>${NC} (e.g. ${CYAN}./install.sh --distro debian${NC}) to override auto-detection."
}

print_common_usage() {
  local script_name
  script_name="$(basename "$0")"
  cat <<EOF
Usage: $script_name [options]

Options:
  -f, --force           Force rebuild/reinstall of optional packages
  -u, --update          Run update tasks (check/install tree-sitter-cli, clean legacy caches, sync config)
  -c, --update-config   Make ~/.config/nvim match the repo (git pull, prune stale files, install new plugins)
  -d, --deps            Check for all dependencies and install missing ones
  -D, --distro <name>   Override distribution detection (e.g. debian, arch, fedora, gentoo)
      --list-distros    List all supported distribution keys and derivatives
      --debug           Enable verbose debug logging
  -h, --help            Show this help message

Examples:
  ./install.sh                      # Auto-detects OS and runs full install
  ./install.sh --distro debian      # Run Debian/Ubuntu installer on derivative OS (e.g. Zorin)
  ./install.sh -u                   # Run update pipeline (deps, tree-sitter-cli, cache cleanup, config sync)
  ./install.sh -c                   # Update the nvim config itself from the repo, including new plugins
  ./install.sh -d                   # Check and install missing dependencies
  ./install.sh --list-distros       # Show supported distributions
EOF
}

parse_common_args() {
  log_debug "Parsing CLI arguments: $*"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -f | --force)
      FORCE_REINSTALL=1
      shift
      ;;
    -u | --update)
      UPDATE_ONLY=1
      shift
      ;;
    -c | --update-config)
      CONFIG_UPDATE=1
      shift
      ;;
    -d | --deps)
      DEPS_ONLY=1
      shift
      ;;
    --debug)
      DEBUG=1
      log_debug "Debug mode enabled"
      shift
      ;;
    --list-distros)
      list_supported_distros
      exit 0
      ;;
    -D | --distro)
      if [ -n "${2:-}" ] && [[ ! "$2" =~ ^- ]]; then
        SPECIFIED_DISTRO="$2"
        shift 2
      else
        log_error "Error: --distro requires a distribution argument."
        exit 1
      fi
      ;;
    --distro=*)
      SPECIFIED_DISTRO="${1#*=}"
      shift
      ;;
    -h | --help)
      print_common_usage
      exit 0
      ;;
    *)
      log_warn "Unknown option: $1"
      print_common_usage
      exit 1
      ;;
    esac
  done
}

# ================================================================================================
# NPM Setup & Management
# ================================================================================================

setup_npm_prefix() {
  NPM_PREFIX="${NPM_PREFIX:-$HOME/.npm-global}"
  log_debug "Setting up npm prefix at: $NPM_PREFIX"
  if command -v npm &>/dev/null; then
    mkdir -p "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX" --location=user 2>/dev/null || npm config set prefix "$NPM_PREFIX" 2>/dev/null || true
    export NPM_CONFIG_PREFIX="$NPM_PREFIX"
    export PATH="$NPM_PREFIX/bin:$PATH"
    log_debug "NPM prefix configured and added to PATH: $PATH"
  fi
}

npm_pkg_installed() {
  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi
  local prefix="${NPM_PREFIX:-$HOME/.npm-global}"
  npm list -g --prefix "$prefix" "$1" >/dev/null 2>&1 || npm list -g "$1" >/dev/null 2>&1
}

# Executables provided by npm packages. Distros may ship the same tooling as
# native packages (e.g. Arch installs bash-language-server via pacman), so
# verification must not assume npm is the only valid source.
npm_pkg_binaries() {
  case "$1" in
  "@fsouza/prettierd") printf '%s\n' prettierd ;;
  "vscode-langservers-extracted")
    printf '%s\n' vscode-html-language-server vscode-css-language-server \
      vscode-json-language-server vscode-eslint-language-server
    ;;
  "bash-language-server") printf '%s\n' bash-language-server ;;
  "@johnnymorganz/stylua-bin") printf '%s\n' stylua ;;
  "pyright") printf '%s\n' pyright pyright-langserver ;;
  "neovim") ;; # node host library, provides no executable
  *) printf '%s\n' "$1" ;;
  esac
}

npm_pkg_binary_available() {
  local bin
  while read -r bin; do
    [ -n "$bin" ] || continue
    if command -v "$bin" >/dev/null 2>&1; then
      return 0
    fi
  done < <(npm_pkg_binaries "$1")
  return 1
}

# Echoes how a package is provided: 'npm', 'system', or 'none'.
detect_pkg_source() {
  if npm_pkg_installed "$1"; then
    printf 'npm\n'
  elif npm_pkg_binary_available "$1"; then
    printf 'system\n'
  else
    printf 'none\n'
  fi
}

install_npm_packages() {
  setup_npm_prefix
  if ! command -v npm &>/dev/null; then
    log_warn "npm not available; skipping npm packages: $*"
    for pkg in "$@"; do
      FAILED_NPM+=("$pkg")
    done
    return 1
  fi

  local pkgs=("$@")
  for pkg in "${pkgs[@]}"; do
    if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed "$pkg"; then
      log_info "Installing npm package: ${pkg}..."
      if npm install -g --prefix "$NPM_PREFIX" "$pkg"; then
        log_success "✓ npm package $pkg installed successfully"
      else
        log_error "✗ Failed to install npm package: $pkg"
        FAILED_NPM+=("$pkg")
      fi
    else
      log_success "✓ npm package $pkg already installed"
    fi
  done
}

# ================================================================================================
# NeoVim Semver & Support Checks
# ================================================================================================

parse_nvim_semver() {
  local ver="$1"
  local a b c
  ver="${ver#v}"
  IFS='.' read -r a b c <<<"$ver"
  a="${a:-0}"
  b="${b:-0}"
  c="${c:-0}"

  if [[ "$a" -eq 0 ]]; then
    printf '%s %s %s\n' "$b" "$c" "0"
  else
    printf '%s %s %s\n' "$a" "$b" "$c"
  fi
}

# ================================================================================================
# Update Tasks Pipeline
# ================================================================================================

clean_legacy_treesitter() {
  log_info "Checking for legacy nvim-treesitter cache..."
  local ts_dir="${HOME}/.local/share/nvim/lazy/nvim-treesitter"
  if [ -d "$ts_dir" ]; then
    log_warn "Removing legacy nvim-treesitter cache (${ts_dir}) for clean main branch migration..."
    rm -rf "$ts_dir"
    log_success "✓ Legacy nvim-treesitter cache removed"
  else
    log_success "✓ No legacy nvim-treesitter directory found"
  fi
}

# nvim-treesitter's main branch needs a recent CLI to compile parsers, and
# several distributions ship something much older (Debian trixie packages 0.22.6,
# Ubuntu 24.04 is older still).
TS_CLI_MIN_VERSION="0.26.1"

version_is_at_least() {
  local have="$1" want="$2"
  [ "$(printf '%s\n%s\n' "$want" "$have" | sort -V | head -n 1)" = "$want" ]
}

treesitter_cli_version() {
  command -v tree-sitter >/dev/null 2>&1 || return 1
  tree-sitter --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

# tree-sitter publishes prebuilt Linux CLI archives, which is far quicker than
# compiling the CLI from source.
install_treesitter_cli_prebuilt() {
  [ "$(uname -s)" = "Linux" ] || return 1

  local arch
  case "$(uname -m)" in
  x86_64 | amd64) arch="x64" ;;
  aarch64 | arm64) arch="arm64" ;;
  armv7l | armv6l | arm) arch="arm" ;;
  i?86) arch="x86" ;;
  ppc64 | ppc64le) arch="powerpc64" ;;
  *) return 1 ;;
  esac

  local tag
  tag="$(curl -fsSL --max-time 30 https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest 2>/dev/null |
    sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  if [ -z "$tag" ]; then
    return 1
  fi

  local tmp
  tmp="$(mktemp -d)"
  local url="https://github.com/tree-sitter/tree-sitter/releases/download/${tag}/tree-sitter-cli-linux-${arch}.zip"
  log_info "Downloading tree-sitter CLI ${tag} (${arch})..."

  if curl -fsSL --max-time 300 -o "${tmp}/ts.zip" "$url"; then
    if command -v unzip >/dev/null 2>&1; then
      unzip -o -q "${tmp}/ts.zip" -d "${tmp}/bin" || true
    elif command -v python3 >/dev/null 2>&1; then
      python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${tmp}/ts.zip" "${tmp}/bin" || true
    fi

    if [ -f "${tmp}/bin/tree-sitter" ]; then
      mkdir -p "${HOME}/.local/bin"
      cp "${tmp}/bin/tree-sitter" "${HOME}/.local/bin/tree-sitter"
      chmod +x "${HOME}/.local/bin/tree-sitter"
      export PATH="${HOME}/.local/bin:$PATH"

      local installed_version
      installed_version="$(treesitter_cli_version || true)"
      if [ -n "$installed_version" ] && version_is_at_least "$installed_version" "$TS_CLI_MIN_VERSION"; then
        rm -rf "$tmp"
        log_success "✓ tree-sitter CLI ${installed_version} installed to ~/.local/bin"
        return 0
      fi
    fi
  fi

  rm -rf "$tmp"
  return 1
}

install_treesitter_cli_cargo() {
  command -v cargo >/dev/null 2>&1 || return 1

  # tree-sitter-cli's build uses bindgen, which needs libclang at build time.
  # OpenBSD/NetBSD keep it under a versioned llvm directory.
  if [ -z "${LIBCLANG_PATH:-}" ]; then
    local libclang_dir
    for libclang_dir in /usr/local/llvm*/lib /usr/local/lib /usr/lib/llvm-*/lib /usr/lib64/llvm*/lib; do
      if compgen -G "${libclang_dir}/libclang.so*" >/dev/null; then
        export LIBCLANG_PATH="$libclang_dir"
        log_debug "Using LIBCLANG_PATH=${LIBCLANG_PATH}"
        break
      fi
    done
  fi

  log_info "Installing tree-sitter-cli via cargo (this can take a few minutes)..."
  if cargo install tree-sitter-cli --root "${HOME}/.local"; then
    export PATH="${HOME}/.local/bin:$PATH"
    log_success "✓ tree-sitter-cli $(treesitter_cli_version || echo '') installed via cargo"
    return 0
  fi
  return 1
}

update_treesitter_cli() {
  log_info "Checking tree-sitter CLI..."

  local ts_version=""
  ts_version="$(treesitter_cli_version || true)"

  if [ -n "$ts_version" ] && version_is_at_least "$ts_version" "$TS_CLI_MIN_VERSION"; then
    log_success "✓ tree-sitter CLI available: $(tree-sitter --version 2>/dev/null || echo 'installed')"
    return 0
  fi

  if [ -n "$ts_version" ]; then
    log_warn "tree-sitter CLI ${ts_version} is older than the required v${TS_CLI_MIN_VERSION}; installing a newer build..."
  else
    log_warn "tree-sitter CLI not found. Installing..."
  fi

  if install_treesitter_cli_prebuilt || install_treesitter_cli_cargo; then
    return 0
  fi

  log_warn "○ tree-sitter CLI v${TS_CLI_MIN_VERSION}+ is required by nvim-treesitter"
  log_warn "  Install it manually with: cargo install tree-sitter-cli"
  return 0
}

# ================================================================================================
# Optional markdown / preview toolchain
# ================================================================================================
# Snacks.image (and other previewers) shell out to `mmdc` for Mermaid diagrams
# and `tectonic`/`pdflatex` for LaTeX math, and report them as errors in
# :checkhealth when they are missing. Neither is packaged by Debian/Ubuntu.
install_tectonic_prebuilt() {
  [ "$(uname -s)" = "Linux" ] || return 1

  local target
  case "$(uname -m)" in
  x86_64 | amd64) target="x86_64-unknown-linux-musl" ;;
  aarch64 | arm64) target="aarch64-unknown-linux-musl" ;;
  armv7l | armv6l | arm) target="arm-unknown-linux-musleabihf" ;;
  i?86) target="i686-unknown-linux-gnu" ;;
  *) return 1 ;;
  esac

  local tag version encoded_tag
  tag="$(curl -fsSL --max-time 30 https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest 2>/dev/null |
    sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  if [ -z "$tag" ]; then
    return 1
  fi
  version="${tag##*@}" # tags look like 'tectonic@0.17.0'
  encoded_tag="${tag/@/%40}"

  local tmp
  tmp="$(mktemp -d)"
  local url="https://github.com/tectonic-typesetting/tectonic/releases/download/${encoded_tag}/tectonic-${version}-${target}.tar.gz"
  log_info "Downloading tectonic ${version} (${target})..."

  if curl -fsSL --max-time 600 -o "${tmp}/tectonic.tar.gz" "$url" &&
    tar -xzf "${tmp}/tectonic.tar.gz" -C "$tmp" && [ -f "${tmp}/tectonic" ]; then
    mkdir -p "${HOME}/.local/bin"
    cp "${tmp}/tectonic" "${HOME}/.local/bin/tectonic"
    chmod +x "${HOME}/.local/bin/tectonic"
    export PATH="${HOME}/.local/bin:$PATH"
    rm -rf "$tmp"
    log_success "✓ tectonic ${version} installed to ~/.local/bin"
    return 0
  fi

  rm -rf "$tmp"
  return 1
}

install_doc_toolchain() {
  if [ "${INSTALL_DOC_TOOLS:-y}" != "y" ]; then
    log_info "Skipping optional markdown/preview tools (INSTALL_DOC_TOOLS=${INSTALL_DOC_TOOLS:-})"
    return 0
  fi

  # Mermaid diagrams (used by Snacks.image for docs previews). The npm package
  # bundles its own browser, so expect a few hundred MB on first install.
  if ! command -v mmdc >/dev/null 2>&1; then
    log_info "Installing mermaid-cli (mmdc) via npm - this pulls a bundled browser..."
    if ! install_npm_packages "@mermaid-js/mermaid-cli"; then
      FAILED_NPM+=("@mermaid-js/mermaid-cli")
    fi
  else
    log_success "✓ mmdc already available"
  fi

  # LaTeX math: tectonic ships static binaries, and a TeX distribution provides
  # pdflatex, so only fetch tectonic when neither is present.
  if command -v tectonic >/dev/null 2>&1; then
    log_success "✓ tectonic already available"
  elif command -v pdflatex >/dev/null 2>&1; then
    log_success "✓ pdflatex already available"
  else
    if ! install_tectonic_prebuilt; then
      log_warn "○ Neither 'tectonic' nor 'pdflatex' is available; LaTeX math in docs previews will not render"
      FAILED_BUILD+=("tectonic")
    fi
  fi
}

sync_neovim_config() {
  local prune="${1:-0}"
  log_info "Syncing bugsvim config to ~/.config/nvim..."
  local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  if [ ! -d "${repo_root}/nvim" ]; then
    log_error "✗ Cannot find 'nvim' source directory in ${repo_root}"
    return 1
  fi
  mkdir -p "${HOME}/.config/nvim"

  # Pruning makes ~/.config/nvim a mirror of the repo: anything that is not in
  # nvim/ is removed, nested files included. A top-level-only prune would miss
  # the case that matters - a plugin spec deleted upstream still loading from
  # lua/plugins/ - because lua/ itself exists in the repo and was never
  # recursed into. -depth visits children before parents, so a directory that no
  # longer exists upstream is emptied and then removed. --update-config takes a
  # backup before calling this with prune=1.
  if [ "$prune" -eq 1 ]; then
    local rel path
    while IFS= read -r -d '' path; do
      rel="${path#"${HOME}/.config/nvim/"}"
      if [ ! -e "${repo_root}/nvim/${rel}" ]; then
        log_debug "Pruning stale entry: ${rel}"
        rm -rf "$path"
      fi
    done < <(find "${HOME}/.config/nvim" -mindepth 1 -depth -print0)
  fi

  # Copy each entry explicitly: 'cp -r nvim/*' does not match dotfiles, so
  # .luacheckrc, .luarc.json and .stylua.toml never reached ~/.config/nvim.
  local entry
  for entry in "${repo_root}/nvim"/* "${repo_root}/nvim"/.[!.]*; do
    [ -e "$entry" ] || continue
    cp -r "$entry" "${HOME}/.config/nvim/"
  done
  log_success "✓ bugsvim config updated in ~/.config/nvim"
}

# ================================================================================================
# Config Update From Repo (--update-config)
# ================================================================================================
# `-u` re-syncs the local checkout, but it never fetches upstream and never
# removes files deleted in the repo, so a removed plugin spec kept loading from
# ~/.config/nvim. `-c` is the "make ~/.config/nvim match the repo" path: pull,
# back up, prune, copy (dotfiles included), then install new plugins.
update_config_from_repo() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Updating the NeoVim config from the repo           ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

  # 1. Sync the upstream version rather than whatever the local checkout holds.
  if [ -d "${repo_root}/.git" ] && command -v git >/dev/null 2>&1; then
    local branch
    branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
      log_info "Pulling latest '${branch}' from origin..."
      if git -C "$repo_root" pull --ff-only; then
        log_success "✓ Repository up to date"
      else
        # --ff-only refuses to guess on a diverged branch or local commits, so
        # leave the checkout alone rather than resetting work the user may want.
        log_warn "⚠ 'git pull --ff-only' failed (local commits or diverged branch); syncing the current checkout"
      fi
    else
      log_info "Detached HEAD: skipping 'git pull', syncing the current checkout"
    fi
  else
    log_info "Not a git checkout: syncing the current files"
  fi
  echo ""

  # 2. Back up ~/.config/nvim before pruning anything out of it.
  backup_config_dir_if_needed
  echo ""

  # 3. Prune stale entries and copy the repo's nvim/ tree, dotfiles included.
  sync_neovim_config 1
  echo ""

  # 4. Install newly added plugins so they are usable on the next launch.
  if command -v nvim >/dev/null 2>&1; then
    log_info "Running 'Lazy sync' to install new plugins (this can take a while)..."
    local sync_log
    sync_log="$(mktemp)"
    if nvim --headless "+Lazy! sync" +qa >"$sync_log" 2>&1; then
      log_success "✓ Plugins synced"
    else
      log_warn "⚠ 'Lazy sync' reported a problem; open nvim and run ':Lazy sync'"
      tail -n 20 "$sync_log" | sed 's/^/    /' || true
    fi
    rm -f "$sync_log"
  else
    log_warn "⚠ nvim not found; run ':Lazy sync' manually once it is installed"
  fi

  echo ""
  log_success "✓ Config update completed successfully!"
  echo "Next steps: restart neovim, then run ':checkhealth' if something looks wrong."
}

# ================================================================================================
# Org-mode notes directory
# ================================================================================================
# The org.nvim plugin spec points org_directory, agenda_files and
# default_notes_file at ~/org, so create it during install: agenda, capture and
# refile otherwise have nowhere to read or write on first use.
#
# Note: the path is lowercase 'org' and must match the plugin's opts exactly -
# '~/Org' is a different directory on case-sensitive filesystems.
# Override with ORG_DIRECTORY=/some/path.
ensure_org_directory() {
  local org_dir="${ORG_DIRECTORY:-${HOME}/org}"
  local notes_file="${org_dir}/refile.org"
  local display="${org_dir/#$HOME/~}"

  if [ -d "$org_dir" ]; then
    log_success "✓ Org directory already exists: ${display}"
  else
    log_info "Creating Org directory: ${display}..."
    if ! mkdir -p "$org_dir"; then
      log_warn "⚠ Could not create ${display}; org.nvim agenda/capture will have nowhere to work"
      return 1
    fi
    log_success "✓ Created ${display}"
  fi

  # default_notes_file: org capture appends to it, so create an empty file.
  if [ ! -f "$notes_file" ]; then
    if : >"$notes_file" 2>/dev/null; then
      log_debug "Created ${notes_file}"
    else
      log_warn "⚠ Could not create ${notes_file}"
    fi
  fi
  return 0
}

run_update_tasks() {
  local distro_title="${1:-Standard}"
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - ${distro_title} Update Tasks                       ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  clean_legacy_treesitter
  echo ""
  update_treesitter_cli
  echo ""
  sync_neovim_config
  echo ""
  log_success "✓ All update tasks completed successfully!"
  echo "Next steps: Launch 'nvim' and run ':Lazy sync' or ':TSUpdate' if needed."
}

# ================================================================================================
# Backup Existing NeoVim Configuration
# ================================================================================================

# Timestamped backup of ~/.config/nvim, taken at most once per run. The full
# installer uses backup_neovim_config (backup + remove); --update-config only
# needs the backup, because it prunes the directory in place.
backup_config_dir_if_needed() {
  if [ "${BACKUP_DONE:-0}" -eq 1 ]; then
    log_debug "Config backup already taken this run"
    return 0
  fi
  BACKUP_DONE=1

  if [ ! -d "${HOME}/.config/nvim" ]; then
    log_info "No existing ~/.config/nvim to back up"
    return 0
  fi

  local timestamp backup_dir
  timestamp=$(date +"%Y%m%d-%H%M%S")
  backup_dir="${HOME}/.config/neovim-backup-${timestamp}"
  mkdir -p "$backup_dir"
  log_info "Backing up ~/.config/nvim before pruning..."
  cp -r "${HOME}/.config/nvim" "${backup_dir}/.config-nvim"
  log_success "✓ Backup created: ${backup_dir}/.config-nvim"
}

backup_neovim_config() {
  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M%S")
  local backup_dir="${HOME}/.config/neovim-backup-${timestamp}"
  local has_config=false

  log_info "Checking for existing NeoVim configuration..."

  if [ -d "${HOME}/.config/nvim" ] || [ -d "${HOME}/.local/share/nvim" ] || [ -d "${HOME}/.local/state/nvim" ]; then
    has_config=true
  fi

  if [ "$has_config" = true ]; then
    log_warn "Found existing NeoVim configuration"

    local do_backup=0
    if [ -t 0 ] && [ "${INTERACTIVE:-y}" = "y" ]; then
      read -p "Backup existing config? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        do_backup=1
      fi
    else
      # Non-interactive runs (CI, 'curl | bash', nohup) must not block on a
      # prompt - and must never delete a config without a backup first.
      log_info "Non-interactive run: backing up the existing config automatically"
      do_backup=1
    fi

    if [ "$do_backup" -eq 1 ]; then
      mkdir -p "$backup_dir"
      log_info "Creating backup in: $backup_dir"

      [ -d "${HOME}/.config/nvim" ] && cp -r "${HOME}/.config/nvim" "$backup_dir/.config-nvim"
      [ -d "${HOME}/.local/share/nvim" ] && cp -r "${HOME}/.local/share/nvim" "$backup_dir/.local-share-nvim"
      [ -d "${HOME}/.local/state/nvim" ] && cp -r "${HOME}/.local/state/nvim" "$backup_dir/.local-state-nvim"

      log_success "✓ Backup created: $backup_dir"
    else
      log_warn "Skipping backup"
    fi

    log_info "Removing existing NeoVim config and state..."
    rm -rf "${HOME}/.config/nvim"
    rm -rf "${HOME}/.local/share/nvim"
    rm -rf "${HOME}/.local/state/nvim"
    log_success "✓ Existing config and state removed"
  else
    log_success "✓ No existing NeoVim configuration found"
  fi

  # Nothing left to back up for the rest of this run.
  BACKUP_DONE=1
}

# ================================================================================================
# Shell Configuration
# ================================================================================================

configure_shell_path() {
  log_info "Configuring shell PATH for user npm and local binaries..."
  local current_shell
  current_shell="$(basename "${SHELL:-bash}")"
  local shell_config=""

  case "$current_shell" in
  zsh)
    shell_config="${HOME}/.zshrc"
    ;;
  bash)
    shell_config="${HOME}/.bashrc"
    ;;
  fish)
    shell_config="${HOME}/.config/fish/config.fish"
    ;;
  *)
    shell_config="${HOME}/.${current_shell}rc"
    log_warn "Note: Detected shell '$current_shell' - using $shell_config"
    ;;
  esac

  # Check both locations separately: an older install may have added
  # ~/.npm-global/bin while ~/.local/bin (ruff, pyright, lua-language-server,
  # hyprls, and the linked fd) is still missing from PATH.
  local need_npm=0
  local need_local=0
  if ! grep -q "npm-global" "$shell_config" 2>/dev/null; then
    need_npm=1
  fi
  if ! grep -q "\.local/bin" "$shell_config" 2>/dev/null; then
    need_local=1
  fi

  local path_line=""
  if [ "$current_shell" = "fish" ]; then
    path_line='set -gx PATH $HOME/.npm-global/bin $HOME/.local/bin $PATH'
  elif [ "$need_npm" -eq 1 ] && [ "$need_local" -eq 1 ]; then
    path_line='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
  elif [ "$need_npm" -eq 1 ]; then
    path_line='export PATH="$HOME/.npm-global/bin:$PATH"'
  else
    path_line='export PATH="$HOME/.local/bin:$PATH"'
  fi

  if [ ! -f "$shell_config" ]; then
    log_warn "Note: Shell config file not found at $shell_config"
    echo -e "Please add the following line to your shell profile manually:\n  $path_line"
    return 0
  fi

  if [ "$need_npm" -eq 0 ] && [ "$need_local" -eq 0 ]; then
    log_success "✓ npm and local bin paths already in $shell_config"
    return 0
  fi

  echo "$path_line" >>"$shell_config"
  log_success "✓ Added the missing PATH entry to $shell_config"
  log_debug "Appended: $path_line"
}

# ================================================================================================
# Verification Helpers
# ================================================================================================

verify_installation() {
  MISSING=0

  echo "Checking core tools:"
  for cmd in nvim git rg fd curl clang; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${RED}✗${NC} $cmd (missing)"
      MISSING=1
    fi
  done

  echo ""
  echo "Checking formatters and linters:"
  for cmd in stylua luacheck shfmt clang-format prettier; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${YELLOW}○${NC} $cmd (not found, but may be optional)"
    fi
  done

  echo ""
  echo "Checking language server packages:"
  if ! command -v npm &>/dev/null; then
    echo -e "  ${YELLOW}○${NC} npm not available (checking for system-provided binaries only)"
  fi
  for pkg in "@fsouza/prettierd" "vscode-langservers-extracted" "bash-language-server"; do
    case "$(detect_pkg_source "$pkg")" in
    npm)
      echo -e "  ${GREEN}✓${NC} $pkg (npm)"
      ;;
    system)
      echo -e "  ${GREEN}✓${NC} $pkg (system package)"
      ;;
    *)
      echo -e "  ${RED}✗${NC} $pkg (missing)"
      MISSING=1
      ;;
    esac
  done

  echo ""
  echo "Checking tree-sitter CLI:"
  if command -v tree-sitter &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} tree-sitter ($(tree-sitter --version 2>/dev/null || echo 'installed'))"
  else
    echo -e "  ${YELLOW}○${NC} tree-sitter (missing, recommended for Treesitter parser compilation)"
  fi
}

# ================================================================================================
# Installation Summary
# ================================================================================================

print_installation_summary() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Installation Summary                                         ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install packages:${NC}"
    for pkg in "${FAILED_PACKAGES[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_NPM[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install npm packages:${NC}"
    for pkg in "${FAILED_NPM[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_PYTHON[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install Python packages:${NC}"
    for pkg in "${FAILED_PYTHON[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_AUR[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install AUR packages:${NC}"
    for pkg in "${FAILED_AUR[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_BUILD[@]} -gt 0 ]; then
    echo -e "${RED}Failed to build/install tools:${NC}"
    for pkg in "${FAILED_BUILD[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  local total_failures=$((${#FAILED_PACKAGES[@]} + ${#FAILED_NPM[@]} + ${#FAILED_PYTHON[@]} + ${#FAILED_AUR[@]} + ${#FAILED_BUILD[@]}))

  if [ $MISSING -eq 0 ] && [ "$total_failures" -eq 0 ]; then
    log_success "✓ Installation completed successfully!"
  else
    log_warn "⚠ Installation completed with some optional components needing attention (see above)."
    log_warn "However, bugsvim config has been installed to ~/.config/nvim."
  fi

  echo ""
  echo "Next steps:"
  echo "  1. Reload your shell profile or restart your terminal"
  echo "  2. Launch neovim: nvim"
  echo "  3. Plugins will auto-install on first launch (lazy.nvim)"
  echo "  4. Treesitter parsers will auto-install (nvim-treesitter)"
  echo "  5. Verify installation inside NeoVim: :checkhealth"
  echo ""
  echo "See POST-INSTALL.md for additional setup and troubleshooting."
}
