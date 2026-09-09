#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Gentoo Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Gentoo Linux
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

# ================================================================================================
# Portage & Repo Helpers
# ================================================================================================

eselect_repo_available() {
  eselect repository list &>/dev/null
}

repo_known() {
  eselect repository list 2>/dev/null | awk '{print $2}' | grep -qx "$1"
}

repo_enabled() {
  eselect repository list -i 2>/dev/null | awk '{print $2}' | grep -qx "$1"
}

ensure_eselect_repository() {
  if ! eselect_repo_available; then
    log_warn "Note: eselect-repository not available, installing..."
    sudo emerge --noreplace app-eselect/eselect-repository || return 1
  fi
}

enable_repo() {
  local repo="$1"
  local sync_type="${2:-}"
  local sync_uri="${3:-}"
  ensure_eselect_repository || return 1

  if repo_enabled "$repo"; then
    log_success "✓ ${repo} repo already enabled"
    return 0
  fi

  if ! repo_known "$repo"; then
    if [ -n "$sync_type" ] && [ -n "$sync_uri" ]; then
      log_warn "Repo '${repo}' not in eselect list; adding via '${sync_type}'..."
      sudo eselect repository add "$repo" "$sync_type" "$sync_uri" || return 1
    else
      log_warn "Warning: repo '${repo}' not found in eselect list"
      return 1
    fi
  fi

  log_info "Enabling repo: ${repo}"
  sudo eselect repository enable "$repo" || return 1
  sudo emaint sync -r "$repo" || sudo emerge --sync || true
  return 0
}

check_and_install_packages() {
  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! qlist -I "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    log_info "Installing missing Portage packages: ${to_install[*]}"
    sudo emerge --noreplace "${to_install[@]}" || {
      FAILED_PACKAGES+=("${to_install[@]}")
      log_warn "Warning: Some Portage packages failed to install"
    }
  else
    log_success "✓ All requested Portage packages already installed"
  fi
}

# ================================================================================================
# NeoVim Version Check
# ================================================================================================

ensure_neovim_supported() {
  local nvim_version="" major minor patch target_atom
  local needs_install=0
  local reason=""

  log_info "Checking NeoVim version..."
  if command -v nvim >/dev/null 2>&1; then
    nvim_version="$(nvim --version | head -1 | grep -oP 'NVIM v\K[^\s]+' || true)"
    if [[ -z "$nvim_version" ]]; then
      needs_install=1
      reason="unable to parse installed NeoVim version"
    else
      read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
      if [[ "$major" -ge 10 ]]; then
        log_success "✓ NeoVim version: ${nvim_version} (supported)"
        return 0
      fi
      needs_install=1
      reason="NeoVim ${nvim_version} detected (requires 0.10+)"
    fi
  else
    needs_install=1
    reason="NeoVim is not installed"
  fi

  if [[ "$needs_install" -eq 1 ]]; then
    log_warn "Note: ${reason}"
    target_atom="app-editors/neovim"
    log_info "Installing supported NeoVim release (${target_atom})..."
    if ! sudo emerge --ask=n --oneshot --autounmask-write --autounmask-continue --binpkg-respect-use=y "$target_atom"; then
      log_error "✗ Failed to install ${target_atom}"
      log_error "Please install NeoVim 0.10+ manually and rerun this script."
      exit 1
    fi
  fi
}

# ================================================================================================
# Dependencies Installation Pipeline
# ================================================================================================

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (Gentoo)      ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Checking and installing Portage packages..."
  check_and_install_packages \
    dev-vcs/git \
    sys-apps/ripgrep \
    sys-apps/fd \
    net-misc/curl \
    app-misc/jq \
    sys-devel/gcc \
    dev-ruby/pkg-config \
    dev-util/tree-sitter-cli \
    dev-lang/lua \
    dev-lua/luarocks \
    dev-lang/python \
    net-libs/nodejs \
    dev-vcs/lazygit \
    sys-apps/bat \
    gui-apps/wl-clipboard || true

  # stylua
  if ! command -v stylua &>/dev/null; then
    sudo emerge --noreplace dev-util/stylua 2>/dev/null || true
  fi

  # luacheck
  if ! command -v luacheck &>/dev/null; then
    if sudo emerge --noreplace dev-lua/luacheck 2>/dev/null; then
      true
    elif command -v luarocks &>/dev/null; then
      sudo luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
    fi
  fi

  # shfmt
  if ! command -v shfmt &>/dev/null; then
    sudo emerge --noreplace dev-util/sh 2>/dev/null || true
  fi

  # ruff
  if ! command -v ruff &>/dev/null; then
    sudo emerge --noreplace dev-util/ruff 2>/dev/null || pip3 install --user ruff 2>/dev/null || true
  fi

  # pyright
  if ! command -v pyright &>/dev/null; then
    if command -v npm &>/dev/null; then
      install_npm_packages pyright || true
    else
      pip3 install --user pyright 2>/dev/null || true
    fi
  fi

  # lua-language-server
  if ! command -v lua-language-server &>/dev/null && ! qlist -I dev-util/lua-language-server &>/dev/null; then
    sudo emerge --noreplace dev-util/lua-language-server 2>/dev/null || true
  fi

  # npm packages
  install_npm_packages prettier @fsouza/prettierd vscode-langservers-extracted bash-language-server

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

# ================================================================================================
# Main Workflow
# ================================================================================================

main() {
  parse_common_args "$@"

  if [ "$UPDATE_ONLY" -eq 1 ]; then
    run_update_tasks "Gentoo Linux"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Gentoo Linux Installation                          ║${NC}"
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
