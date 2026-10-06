#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Gentoo Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Gentoo Linux
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
    # emerge aborts when any atom cannot be satisfied, so one unknown atom used
    # to leave every other package unmerged.
    install_packages_resilient "sudo emerge --noreplace" "${to_install[@]}" || true
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

  # lazygit, stylua and lua-language-server are not in the main tree; they live in
  # the GURU overlay, which the per-tool steps below expect to be enabled.
  enable_repo guru git https://anongit.gentoo.org/git/repo/proj/guru.git || true

  log_info "Checking and installing Portage packages..."
  check_and_install_packages \
    dev-vcs/git \
    sys-apps/ripgrep \
    sys-apps/fd \
    net-misc/curl \
    app-misc/jq \
    sys-devel/gcc \
    dev-util/pkgconf \
    dev-util/tree-sitter-cli \
    dev-lang/lua \
    dev-lua/luarocks \
    dev-lang/python \
    net-libs/nodejs \
    llvm-core/clang \
    sys-apps/bat \
    gui-apps/wl-clipboard || true

  # lazygit (GURU overlay)
  if ! command -v lazygit &>/dev/null; then
    if ! sudo emerge --noreplace dev-vcs/lazygit 2>/dev/null; then
      log_warn "○ lazygit (not available; the GURU overlay provides it)"
      FAILED_PACKAGES+=("lazygit")
    fi
  fi

  # stylua (GURU overlay)
  if ! command -v stylua &>/dev/null; then
    if ! sudo emerge --noreplace dev-util/stylua 2>/dev/null; then
      log_warn "○ stylua (not available; the GURU overlay provides it)"
      FAILED_PACKAGES+=("stylua")
    fi
  fi

  # luacheck
  if ! command -v luacheck &>/dev/null; then
    if sudo emerge --noreplace dev-lua/luacheck 2>/dev/null; then
      true
    elif command -v luarocks &>/dev/null; then
      sudo luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
    fi
  fi

  # shfmt (not in the main tree; GURU provides it)
  if ! command -v shfmt &>/dev/null; then
    if ! sudo emerge --noreplace dev-util/shfmt 2>/dev/null; then
      log_warn "○ shfmt (not available; install from GURU or run 'go install mvdan.cc/sh/v3/cmd/shfmt@latest')"
      FAILED_BUILD+=("shfmt")
    fi
  fi

  # ruff
  if ! command -v ruff &>/dev/null; then
    sudo emerge --noreplace dev-util/ruff 2>/dev/null || pip3 install --user ruff 2>/dev/null || {
      log_warn "○ ruff (install failed)"
      FAILED_PYTHON+=("ruff")
    }
  fi

  # pyright
  if ! command -v pyright &>/dev/null; then
    if command -v npm &>/dev/null; then
      install_npm_packages pyright || true
    else
      pip3 install --user pyright 2>/dev/null || true
    fi
  fi

  # lua-language-server (GURU overlay)
  if ! command -v lua-language-server &>/dev/null && ! qlist -I dev-util/lua-language-server &>/dev/null; then
    if ! sudo emerge --noreplace dev-util/lua-language-server 2>/dev/null; then
      log_warn "○ lua-language-server (not available; the GURU overlay provides it)"
      FAILED_PACKAGES+=("lua-language-server")
    fi
  fi

  # npm packages
  install_npm_packages prettier @fsouza/prettierd vscode-langservers-extracted bash-language-server

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

  if [ "$CONFIG_UPDATE" -eq 1 ]; then
    update_config_from_repo
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
  ensure_org_directory

  echo ""
  configure_shell_path

  print_installation_summary
}

main "$@"
