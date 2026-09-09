#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Bazzite (Fedora Atomic / Universal Blue)
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Bazzite
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

USE_BREW=0
if command -v brew >/dev/null 2>&1; then
  USE_BREW=1
fi

pkg_label() {
  if [ "$USE_BREW" -eq 1 ]; then
    echo "brew"
  else
    echo "rpm-ostree"
  fi
}

pkg_install() {
  if [ "$USE_BREW" -eq 1 ]; then
    brew install "$@"
  else
    sudo rpm-ostree install -y "$@"
  fi
}

pkg_update() {
  if [ "$USE_BREW" -eq 1 ]; then
    brew update
  else
    sudo rpm-ostree upgrade
  fi
}

ensure_neovim_supported() {
  log_info "Checking NeoVim version..."
  if ! command -v nvim &>/dev/null; then
    log_info "NeoVim is not installed. Installing via $(pkg_label)..."
    pkg_install neovim || true
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
    log_warn "Please upgrade NeoVim: $( [ "$USE_BREW" -eq 1 ] && echo 'brew upgrade neovim' || echo 'sudo rpm-ostree upgrade' )"
    exit 1
  fi
  log_success "✓ NeoVim version: $nvim_version (supported)"
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (Bazzite)     ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Installing core and development dependencies via $(pkg_label)..."
  if [ "$USE_BREW" -eq 1 ]; then
    pkg_install \
      git ripgrep fd curl jq pkg-config tree-sitter \
      gcc make automake autoconf \
      lua luarocks python node llvm rust \
      shfmt clang-format lazygit bat || true
  else
    pkg_install \
      git ripgrep fd curl jq pkg-config tree-sitter \
      gcc gcc-c++ make automake autoconf \
      lua luarocks python3-devel python3-pip nodejs npm clang clang-tools-extra rust \
      shfmt lazygit bat wl-clipboard || true
  fi

  # Luacheck
  if command -v luacheck &>/dev/null; then
    log_success "✓ luacheck already installed"
  elif [ "$USE_BREW" -eq 1 ] && command -v brew &>/dev/null && brew install luacheck 2>/dev/null; then
    log_success "✓ luacheck installed via brew"
  elif command -v luarocks &>/dev/null; then
    if luarocks install --local luacheck 2>/dev/null || sudo luarocks install luacheck 2>/dev/null; then
      log_success "✓ luacheck installed via luarocks"
    else
      log_warn "Warning: luacheck install via luarocks failed"
      FAILED_PACKAGES+=("luacheck")
    fi
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

  # NPM packages
  install_npm_packages \
    @johnnymorganz/stylua-bin \
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
    run_update_tasks "Bazzite"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Bazzite Installation                               ║${NC}"
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
