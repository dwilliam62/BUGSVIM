#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Debian / Ubuntu & Derivatives
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Debian/Ubuntu/Mint/Pop/Zorin
# ================================================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Source shared library
if [ -f "${SCRIPT_DIR}/lib/common.sh" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/common.sh"
else
  echo "Error: Cannot find '${SCRIPT_DIR}/lib/common.sh'." >&2
  exit 1
fi

ensure_neovim_supported() {
  log_info "Checking NeoVim version..."
  if ! command -v nvim &>/dev/null; then
    log_warn "NeoVim is not installed. Attempting apt install..."
    sudo apt-get update && sudo apt-get install -y neovim || true
  fi

  local nvim_version
  nvim_version="$(nvim --version 2>/dev/null | head -1 | grep -oP 'NVIM v\K[^\s]+' || true)"
  if [ -z "$nvim_version" ]; then
    log_error "✗ NeoVim is not installed or version could not be parsed."
    echo -e "${YELLOW}Please install NeoVim 0.10+ (e.g., from https://github.com/neovim/neovim/releases or pre-built packages).${NC}"
    exit 1
  fi

  local major minor patch
  read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
  if [ "$major" -lt 10 ]; then
    log_error "✗ NeoVim 0.10+ is required, but found: $nvim_version"
    echo -e "${YELLOW}Debian/Ubuntu official repos may package older versions of NeoVim.${NC}"
    echo -e "${YELLOW}You can obtain NeoVim 0.10+ via AppImage or from https://github.com/neovim/neovim/releases${NC}"
    exit 1
  fi
  log_success "✓ NeoVim version: $nvim_version (supported)"
}

build_hyprls() {
  if command -v hyprls >/dev/null 2>&1; then
    log_success "✓ hyprls already installed"
    return 0
  fi

  local reply="n"
  if [ -t 0 ] && [ "${INTERACTIVE:-y}" = "y" ]; then
    read -p "Optional: Build hyprls (Hyprland LSP) from source? (y/n) " -n 1 -r
    echo
    reply="$REPLY"
  fi

  if [[ $reply =~ ^[Yy]$ ]]; then
    log_info "Installing hyprls build dependencies..."
    sudo apt-get install -y golang-go || true

    if ! command -v go >/dev/null 2>&1; then
      log_warn "⚠ Go compiler not found; skipping hyprls build"
      FAILED_BUILD+=("hyprls")
      return 0
    fi

    mkdir -p "$HOME/.local/bin"
    log_info "Installing hyprls via go install..."
    if GOBIN="$HOME/.local/bin" go install github.com/hyprland-community/hyprls/cmd/hyprls@latest 2>&1 | tee /tmp/hyprls-build.log; then
      log_success "✓ hyprls installed to $HOME/.local/bin"
    else
      log_warn "⚠ hyprls build failed (see /tmp/hyprls-build.log)"
      FAILED_BUILD+=("hyprls")
    fi
  else
    log_info "Skipping optional hyprls build"
  fi
}

# Debian/Ubuntu rename a couple of the tools this config uses:
#   fd  -> fdfind (or fd-find), with the real 'fd' binary outside PATH in
#          /usr/lib/cargo/bin
#   bat -> batcat (to avoid a name clash with another package)
# Link whichever variant exists into ~/.local/bin under the expected name.
link_debian_binary() {
  local wanted="$1"
  shift

  if command -v "$wanted" &>/dev/null; then
    log_success "✓ $wanted already available ($(command -v "$wanted"))"
    return 0
  fi

  local candidate
  for candidate in "$@"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$candidate" "$HOME/.local/bin/$wanted"
      export PATH="${HOME}/.local/bin:$PATH"
      log_success "✓ $wanted linked: ~/.local/bin/$wanted -> $candidate"
      return 0
    fi
  done
  return 1
}

find_fd_binary() {
  local candidate
  for candidate in \
    "$(command -v fdfind 2>/dev/null || true)" \
    "$(command -v fd-find 2>/dev/null || true)" \
    /usr/bin/fdfind \
    /usr/bin/fd-find \
    /usr/lib/cargo/bin/fd \
    /usr/lib/cargo/bin/fd-find \
    /usr/local/lib/cargo/bin/fd; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # Last resort: ask dpkg what the package actually installed
  if command -v dpkg >/dev/null 2>&1; then
    candidate="$(dpkg -L fd-find 2>/dev/null | grep -E '/(fd|fdfind|fd-find)$' | head -n 1 || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 1
}

link_fd_binary() {
  if command -v fd &>/dev/null; then
    log_success "✓ fd already available ($(command -v fd))"
    return 0
  fi

  local fd_bin=""
  fd_bin="$(find_fd_binary || true)"

  if [ -z "$fd_bin" ]; then
    log_info "Installing fd-find (Debian/Ubuntu package fd under that name)..."
    install_packages_resilient "sudo apt-get install -y" fd-find || true
    fd_bin="$(find_fd_binary || true)"
  fi

  if [ -z "$fd_bin" ]; then
    log_warn "⚠ Unable to locate the fd binary; install 'fd-find' manually and link it to 'fd'"
    FAILED_PACKAGES+=("fd")
    return 1
  fi

  log_info "Linking fd -> ${fd_bin}..."
  mkdir -p "$HOME/.local/bin"
  ln -sf "$fd_bin" "$HOME/.local/bin/fd"
  export PATH="${HOME}/.local/bin:$PATH"
  log_success "✓ fd available as ~/.local/bin/fd -> ${fd_bin}"
}

link_bat_binary() {
  link_debian_binary bat \
    "$(command -v batcat 2>/dev/null || true)" \
    /usr/bin/batcat \
    /usr/local/bin/batcat \
    "$(command -v bat 2>/dev/null || true)" ||
    log_warn "⚠ Unable to locate the bat binary; install 'bat' manually and link it to 'bat'"
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (Debian/Ubuntu)║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Updating package lists..."
  sudo apt-get update || true

  local apt_pkgs=(
    git
    ripgrep
    fd-find
    curl
    jq
    build-essential
    pkg-config
    tree-sitter-cli
    lua5.1
    luarocks
    lua-check
    python3-venv
    python3-pip
    nodejs
    npm
    clang
    clangd
    clang-tools
    shfmt
    clang-format
    lazygit
    bat
    wl-clipboard
    rustup
  )

  # apt-get installs nothing at all when one name cannot be located, so a single
  # unavailable package used to skip the whole list.
  log_info "Installing system packages via apt..."
  install_packages_resilient "sudo apt-get install -y" "${apt_pkgs[@]}" || true

  # Older releases package luacheck under its own name rather than lua-check
  if ! command -v luacheck &>/dev/null; then
    install_packages_resilient "sudo apt-get install -y" luacheck || true
  fi

  # Debian/Ubuntu do not package lua-language-server, so use the upstream release
  install_lua_language_server_from_release || true

  link_fd_binary
  link_bat_binary

  # Luacheck fallback via luarocks
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    log_info "Installing luacheck via luarocks..."
    sudo luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # Python packages
  if ! command -v ruff &>/dev/null || ! command -v pyright &>/dev/null; then
    log_info "Installing Python packages (ruff, pyright)..."
    pip3 install --user --break-system-packages ruff pyright 2>/dev/null || \
      python3 -m pip install --user --break-system-packages ruff pyright 2>/dev/null || {
        FAILED_PYTHON+=("ruff" "pyright")
        log_warn "Warning: Python packages failed to install"
      }
  fi

  # NPM global packages
  install_npm_packages \
    bash-language-server \
    @johnnymorganz/stylua-bin \
    prettier \
    @fsouza/prettierd \
    vscode-langservers-extracted

  build_hyprls

  update_treesitter_cli

  install_doc_toolchain

  echo ""
  log_info "Verifying dependencies..."
  echo ""
  verify_installation
  echo ""
  if [ $MISSING -eq 0 ]; then
    log_success "✓ All dependencies are satisfied!"
  else
    log_warn "⚠ Some dependencies are missing (see above)"
  fi
}

main() {
  parse_common_args "$@"

  if [ "$UPDATE_ONLY" -eq 1 ]; then
    run_update_tasks "Debian / Ubuntu"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Debian / Ubuntu Installation                       ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  ensure_neovim_supported
  echo ""

  backup_neovim_config
  echo ""

  check_and_install_deps

  echo ""
  sync_neovim_config

  echo ""
  configure_shell_path

  print_installation_summary
}

main "$@"
