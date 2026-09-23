#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for NetBSD
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on NetBSD
# ================================================================================================

set -euo pipefail

# Ensure standard NetBSD package and local binary directories are in PATH
export PATH="/usr/local/bin:/usr/pkg/bin:${PATH}"

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
    log_info "NeoVim is not installed. Installing via pkgin..."
    run_as_root pkgin -y in neovim || true
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
    log_warn "Please upgrade NeoVim: doas pkgin in neovim"
    exit 1
  fi
  log_success "✓ NeoVim version: $nvim_version (supported)"
}

setup_netbsd_symlinks() {
  log_info "Setting up NetBSD command symlinks in /usr/local/bin..."
  run_as_root mkdir -p /usr/local/bin

  # python3
  if ! command -v python3 &>/dev/null; then
    local py_bin
    py_bin="$(ls /usr/pkg/bin/python3.* 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$py_bin" ] && [ -x "$py_bin" ]; then
      log_info "Creating symlink for python3 -> $py_bin..."
      run_as_root ln -sf "$py_bin" /usr/local/bin/python3 || true
    fi
  fi

  # pip / pip3
  if ! command -v pip3 &>/dev/null || ! command -v pip &>/dev/null; then
    local pip_bin
    pip_bin="$(ls /usr/pkg/bin/pip-* 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$pip_bin" ] && [ -x "$pip_bin" ]; then
      log_info "Creating symlink for pip/pip3 -> $pip_bin..."
      run_as_root ln -sf "$pip_bin" /usr/local/bin/pip3 || true
      run_as_root ln -sf "$pip_bin" /usr/local/bin/pip || true
    fi
  fi

  # luarocks
  if ! command -v luarocks &>/dev/null; then
    local lr_bin
    lr_bin="$(ls /usr/pkg/bin/luarocks-* 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$lr_bin" ] && [ -x "$lr_bin" ]; then
      log_info "Creating symlink for luarocks -> $lr_bin..."
      run_as_root ln -sf "$lr_bin" /usr/local/bin/luarocks || true
    fi
  fi

  # luacheck: prefer luacheck-5.1 if available, else luacheck-5.4
  if ! command -v luacheck &>/dev/null; then
    local lc_bin=""
    if [ -x "/usr/pkg/bin/luacheck-5.1" ]; then
      lc_bin="/usr/pkg/bin/luacheck-5.1"
    elif [ -x "/usr/pkg/bin/luacheck-5.4" ]; then
      lc_bin="/usr/pkg/bin/luacheck-5.4"
    fi
    if [ -n "$lc_bin" ]; then
      log_info "Creating symlink for luacheck -> $lc_bin..."
      run_as_root ln -sf "$lc_bin" /usr/local/bin/luacheck || true
    fi
  fi
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (NetBSD)      ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Updating NetBSD packages via pkgin..."
  run_as_root pkgin -y update || true

  log_info "Installing NetBSD packages via pkgin..."
  run_as_root pkgin -y in \
    git \
    ripgrep \
    fd-find \
    curl \
    jq \
    gmake \
    tree-sitter-cli \
    lua54 \
    lua54-rocks \
    lua51-check \
    python313 \
    py313-pip \
    nodejs \
    llvm \
    clang \
    bash \
    shfmt \
    stylua \
    lazygit \
    bat \
    xclip \
    rust-bin || true

  # Ensure pkgconf or pkg-config is available
  if ! command -v pkg-config &>/dev/null && ! command -v pkgconf &>/dev/null; then
    run_as_root pkgin -y in pkgconf 2>/dev/null || run_as_root pkgin -y in pkg-config 2>/dev/null || true
  fi

  setup_netbsd_symlinks

  # Luacheck fallback via luarocks
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    log_info "Installing luacheck via luarocks..."
    run_as_root luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # Rust toolchain fallback
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
    run_update_tasks "NetBSD"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - NetBSD Installation                                ║${NC}"
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
