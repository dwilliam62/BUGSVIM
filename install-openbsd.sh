#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for OpenBSD
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on OpenBSD
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
    log_info "NeoVim is not installed. Installing via pkg_add..."
    run_as_root pkg_add neovim || true
  fi

  local nvim_version
  nvim_version="$(nvim --version 2>/dev/null | head -1 | sed -E 's/^NVIM v([^[:space:]]+).*/\1/' || true)"
  if [ -z "$nvim_version" ]; then
    log_error "✗ Unable to verify NeoVim version"
    exit 1
  fi

  local major minor patch
  read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
  if [ "$major" -lt 10 ]; then
    log_error "✗ NeoVim 0.10+ is required, but found: $nvim_version"
    log_warn "Please upgrade NeoVim: doas pkg_add -u neovim"
    exit 1
  fi
  log_success "✓ NeoVim version: $nvim_version (supported)"
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (OpenBSD)     ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Updating OpenBSD packages..."
  run_as_root pkg_add -u || true

  log_info "Installing OpenBSD packages via pkg_add..."
  run_as_root pkg_add \
    git \
    ripgrep \
    fd \
    curl \
    jq \
    gmake \
    pkgconf \
    tree-sitter \
    lua \
    luarocks--lua51 \
    python%3 \
    py3-pip \
    node \
    npm \
    llvm \
    bash \
    shfmt \
    stylua \
    lazygit \
    bat \
    xclip || true
  run_as_root pkg_add luacheck 2>/dev/null || true

  # Luacheck fallback via luarocks
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    log_info "Installing luacheck via luarocks..."
    run_as_root luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # Rust
  if ! command -v rustc &>/dev/null; then
    log_info "Installing Rust toolchain via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || true
  fi

  # NPM packages
  install_npm_packages \
    bash-language-server \
    prettier \
    @fsouza/prettierd \
    vscode-langservers-extracted \
    neovim

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
    run_update_tasks "OpenBSD"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - OpenBSD Installation                               ║${NC}"
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
