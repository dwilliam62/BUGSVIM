#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for openSUSE
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on openSUSE (Tumbleweed/Leap)
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
    log_info "NeoVim is not installed. Installing via zypper..."
    sudo zypper install -y neovim || true
  fi

  local nvim_version
  nvim_version="$(nvim --version 2>/dev/null | head -1 | grep -oP 'NVIM v\K[^\s]+' || true)"
  if [ -z "$nvim_version" ]; then
    log_error "✗ Unable to verify NeoVim version"
    exit 1
  fi

  local major minor patch
  read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
  if [ "$major" -lt 10 ]; then
    log_error "✗ NeoVim 0.10+ is required, but found: $nvim_version"
    log_warn "Please upgrade NeoVim: sudo zypper update neovim"
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
    sudo zypper install -y go || true

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

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (openSUSE)    ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Installing openSUSE packages via zypper..."
  sudo zypper install -y \
    neovim \
    git \
    ripgrep \
    fd \
    curl \
    jq \
    gcc \
    gcc-c++ \
    make \
    pkg-config \
    tree-sitter-cli \
    lua \
    luarocks \
    python3 \
    python3-pip \
    nodejs \
    npm \
    clang \
    clang-tools \
    lua-language-server \
    shfmt \
    lazygit \
    bat \
    wl-clipboard || true
  sudo zypper install -y lua-luacheck 2>/dev/null || sudo zypper install -y luacheck 2>/dev/null || true

  # Luacheck fallback via luarocks
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    log_info "Installing luacheck via luarocks..."
    sudo luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # Python packages
  if ! command -v ruff &>/dev/null || ! command -v pyright &>/dev/null; then
    log_info "Installing Python packages (ruff, pyright)..."
    pip3 install --user ruff pyright 2>/dev/null || \
      python3 -m pip install --user ruff pyright 2>/dev/null || {
        FAILED_PYTHON+=("ruff" "pyright")
        log_warn "Warning: Python packages failed to install"
      }
  fi

  # NPM packages
  install_npm_packages \
    bash-language-server \
    @johnnymorganz/stylua-bin \
    prettier \
    @fsouza/prettierd \
    vscode-langservers-extracted \
    neovim

  build_hyprls

  update_treesitter_cli

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
    run_update_tasks "openSUSE"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - openSUSE Installation                              ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  ensure_neovim_supported
  echo ""

  backup_neovim_config
  echo ""

  log_info "Step 1: Refreshing zypper repositories..."
  sudo zypper refresh || true

  check_and_install_deps

  echo ""
  sync_neovim_config

  echo ""
  configure_shell_path

  print_installation_summary
}

main "$@"
