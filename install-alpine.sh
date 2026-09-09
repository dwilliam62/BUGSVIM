#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Alpine Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Alpine Linux
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
    log_info "NeoVim is not installed. Installing via apk..."
    run_as_root apk add --no-interactive neovim || true
  fi

  local nvim_version
  nvim_version="$(nvim --version 2>/dev/null | head -1 | sed -n '1{s/^NVIM v//;s/ .*//;p}')"
  if [ -z "$nvim_version" ]; then
    log_warn "Warning: Could not parse NeoVim version; continuing..."
    return 0
  fi

  local major minor patch
  read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
  if [ "$major" -lt 10 ]; then
    log_warn "⚠ NeoVim 0.10+ is recommended for this config (found: $nvim_version)"
    log_warn "You can try newer packages from your Alpine branch (main/community/edge)."
  else
    log_success "✓ NeoVim version: $nvim_version (supported)"
  fi
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (Alpine)      ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Updating package indexes..."
  run_as_root apk update || true

  log_info "Installing apk packages..."
  run_as_root apk add --no-interactive \
    git \
    ripgrep \
    fd \
    curl \
    jq \
    build-base \
    pkgconf \
    tree-sitter-cli \
    lua5.1 \
    luarocks \
    python3 \
    py3-pip \
    nodejs \
    npm \
    rust \
    clang \
    cmd:clangd \
    cmd:clang-format \
    shfmt \
    stylua \
    luacheck \
    lua5.1-luacheck \
    lazygit \
    bat \
    wl-clipboard \
    py3-ruff \
    py3-pyright || true

  # lua-language-server (community repo)
  if ! command -v lua-language-server &>/dev/null; then
    log_info "Installing lua-language-server via apk community..."
    run_as_root apk add --no-interactive lua-language-server 2>/dev/null || {
      log_warn "Warning: lua-language-server install failed (ensure 'community' repo is enabled)"
      FAILED_PACKAGES+=("lua-language-server")
    }
  fi

  # Luacheck fallback via luarocks
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    log_info "Installing luacheck via luarocks..."
    run_as_root luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # Python packages fallback
  if ! command -v ruff &>/dev/null; then
    pip3 install --user ruff 2>/dev/null || true
  fi
  if ! command -v pyright-langserver &>/dev/null && ! command -v pyright &>/dev/null; then
    pip3 install --user pyright 2>/dev/null || true
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
    run_update_tasks "Alpine Linux"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Alpine Linux Installation                          ║${NC}"
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
