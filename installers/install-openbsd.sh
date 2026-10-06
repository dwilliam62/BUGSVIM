#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for OpenBSD
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on OpenBSD
# ================================================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source shared library
if [ -f "${REPO_ROOT}/lib/common.sh" ]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/lib/common.sh"
else
  echo "Error: Cannot find '${REPO_ROOT}/lib/common.sh'." >&2
  exit 1
fi

# OpenBSD ships version-suffixed luarocks binaries (luarocks-5.4), while the
# rest of the tooling expects a plain 'luarocks' on PATH.
setup_openbsd_symlinks() {
  if ! command -v luarocks &>/dev/null; then
    local lr_bin
    lr_bin="$(ls /usr/local/bin/luarocks-[0-9]* 2>/dev/null | sort -V | tail -n 1 || true)"
    if [ -n "$lr_bin" ] && [ -x "$lr_bin" ]; then
      log_info "Creating symlink for luarocks -> $lr_bin..."
      mkdir -p "$HOME/.local/bin"
      run_as_root ln -sf "$lr_bin" /usr/local/bin/luarocks || ln -sf "$lr_bin" "$HOME/.local/bin/luarocks" || true
      export PATH="${HOME}/.local/bin:$PATH"
    fi
  fi
}

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

  # NOTE: OpenBSD packages no pkgconf, npm (the node package provides npm) or
  # lazygit; the Lua rocks build is the luarocks-lua54 subpackage, and clangd /
  # clang-format live in clang-tools-extra rather than llvm.
  local openbsd_pkgs=(
    git
    ripgrep
    fd
    curl
    jq
    gmake
    tree-sitter
    lua
    luarocks-lua54
    lua-language-server
    python%3
    py3-pip
    node
    llvm
    clang-tools-extra
    bash
    shfmt
    stylua
    bat
    xclip
  )

  # pkg_add reports the packages it could not find instead of failing the whole
  # run, but keep the same retry/report behaviour for consistency.
  log_info "Installing OpenBSD packages via pkg_add..."
  install_packages_resilient "run_as_root pkg_add" "${openbsd_pkgs[@]}" || true
  install_packages_resilient "run_as_root pkg_add" luacheck || true

  setup_openbsd_symlinks

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

  # Python packages. OpenBSD marks its Python as externally managed, and ruff has
  # no BSD package or wheel, so pip compiles it from source (slow, and it can
  # fail on small VMs). Install them separately so a ruff build failure cannot
  # block pyright, which is pure Python.
  if ! command -v pyright &>/dev/null && ! command -v pyright-langserver &>/dev/null; then
    log_info "Installing pyright via pip..."
    if python3 -m pip install --user --break-system-packages pyright 2>/dev/null ||
      pip3 install --user --break-system-packages pyright 2>/dev/null; then
      log_success "✓ pyright installed"
    else
      FAILED_PYTHON+=("pyright")
      log_warn "Warning: pyright install failed"
    fi
  fi
  if ! command -v ruff &>/dev/null; then
    log_info "Installing ruff via pip (compiles from source on BSD)..."
    if python3 -m pip install --user --break-system-packages ruff 2>/dev/null ||
      pip3 install --user --break-system-packages ruff 2>/dev/null; then
      log_success "✓ ruff installed"
    else
      FAILED_PYTHON+=("ruff")
      log_warn "Warning: ruff install failed (no BSD wheel, source build failed)"
    fi
  fi

  # NPM packages
  install_npm_packages \
    bash-language-server \
    prettier \
    @fsouza/prettierd \
    vscode-langservers-extracted \
    neovim

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
    run_update_tasks "OpenBSD"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  if [ "$CONFIG_UPDATE" -eq 1 ]; then
    update_config_from_repo
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
  ensure_org_directory

  echo ""
  configure_shell_path

  print_installation_summary
}

main "$@"
