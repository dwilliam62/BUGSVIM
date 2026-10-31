#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Arch Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Arch Linux
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
# Arch / AUR Helpers
# ================================================================================================

ensure_neovim_supported() {
  log_info "Checking NeoVim version..."
  if ! command -v nvim &>/dev/null; then
    log_info "NeoVim not installed. Installing via pacman..."
    sudo pacman -S --needed --noconfirm neovim
  fi

  local nvim_version
  nvim_version="$(nvim --version | head -1 | grep -oP 'NVIM v\K[^\s]+' || true)"
  if [ -z "$nvim_version" ]; then
    log_error "✗ Unable to verify NeoVim version"
    exit 1
  fi

  local major minor patch
  read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
  if [ "$major" -lt 10 ]; then
    log_error "✗ NeoVim 0.10+ is required, but found: $nvim_version"
    log_warn "Please upgrade NeoVim: sudo pacman -Syyu neovim"
    exit 1
  fi
  log_success "✓ NeoVim version: $nvim_version (supported)"
}

install_aur_packages() {
  log_info "Checking for AUR helper (yay/paru)..."
  local aur_cmd=""
  if command -v yay &>/dev/null; then
    aur_cmd="yay"
  elif command -v paru &>/dev/null; then
    aur_cmd="paru"
  fi

  # 'alejandra' (not 'alejandra-bin', which does not exist in the AUR).
  # prettierd is deliberately absent: the upstream @fsouza/prettierd npm package
  # is already installed just above and the AUR PKGBUILD is flagged out-of-date.
  local aur_pkgs=(alejandra)
  if ! command -v hyprls >/dev/null 2>&1; then
    aur_pkgs+=(hyprls)
  fi

  if [ -n "$aur_cmd" ]; then
    log_info "Installing AUR packages via $aur_cmd: ${aur_pkgs[*]}..."
    local aur_args=(--noconfirm)
    [ "$FORCE_REINSTALL" -ne 1 ] && aur_args+=(--needed)

    # Like pacman, yay/paru resolve every target before building, so one
    # renamed or removed package aborts the whole transaction and nothing is
    # installed. Install the batch, then retry one at a time so the resolvable
    # names still land and only the genuinely unavailable ones are reported.
    if ! "$aur_cmd" -S "${aur_args[@]}" "${aur_pkgs[@]}"; then
      log_warn "⚠ AUR batch install failed; retrying packages individually..."
      for pkg in "${aur_pkgs[@]}"; do
        if "$aur_cmd" -S "${aur_args[@]}" "$pkg"; then
          log_success "✓ $pkg"
        else
          log_warn "○ $pkg (failed)"
          FAILED_AUR+=("$pkg")
        fi
      done
    fi
  else
    log_warn "⚠ No AUR helper found (yay/paru). Optional AUR packages skipped: ${aur_pkgs[*]}"
    FAILED_AUR+=("${aur_pkgs[@]}")
  fi
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (Arch)        ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  local pacman_pkgs=(
    git ripgrep fd curl jq base-devel pkg-config tree-sitter-cli
    lua-language-server luarocks luacheck
    python python-pip python-pynvim
    nodejs npm
    clang
    bash-language-server
    stylua shfmt prettier pyright ruff wl-clipboard lazygit bat
    go gopls zig zls golangci-lint
  )

  local missing_pacman=()
  for pkg in "${pacman_pkgs[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
      missing_pacman+=("$pkg")
    fi
  done

  if [ ${#missing_pacman[@]} -gt 0 ]; then
    log_info "Installing missing pacman packages: ${missing_pacman[*]}..."
    # pacman aborts the whole transaction on an unknown target, so one bad name
    # used to leave every other package uninstalled.
    install_packages_resilient "sudo pacman -S --needed --noconfirm" "${missing_pacman[@]}" || true
  else
    log_success "✓ All core pacman packages installed"
  fi

  # Rust toolchain check
  if ! command -v rustc &>/dev/null && ! pacman -Q rustup &>/dev/null && ! pacman -Q rust &>/dev/null; then
    log_info "Installing rustup..."
    sudo pacman -S --needed --noconfirm rustup || true
  fi

  # Luacheck fallback
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    log_info "Installing luacheck via luarocks..."
    sudo luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # NPM global packages
  install_npm_packages @fsouza/prettierd vscode-langservers-extracted neovim

  # AUR Packages
  install_aur_packages

  update_treesitter_cli

  install_go_zig_support

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
    run_update_tasks "Arch Linux"
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
  echo -e "${BLUE}║   bugsvim - Arch Linux Installation                            ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  ensure_neovim_supported
  echo ""

  backup_neovim_config
  echo ""

  log_info "Step 1: Updating package manager database..."
  sudo pacman -Sy --noconfirm

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
