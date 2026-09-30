#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Fedora & Derivatives
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Fedora Linux
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
# Fedora / dnf Helpers
# ================================================================================================

# Install dnf packages without letting a single unavailable name abort the
# whole transaction. dnf resolves all arguments before installing anything, so
# one package that does not exist (e.g. shfmt on Fedora) silently prevents every
# other package in the list from being installed.
dnf_install_packages() {
  local dnf_bin="dnf"
  if command -v dnf5 >/dev/null 2>&1; then
    dnf_bin="dnf5"
  fi

  local skip_flag="--skip-broken --setopt=strict=0"
  if [ "$dnf_bin" = "dnf5" ]; then
    skip_flag="--skip-unavailable"
  fi

  log_info "Installing Fedora packages via ${dnf_bin}..."
  install_packages_resilient "sudo $dnf_bin install -y $skip_flag" "$@"
}

ensure_neovim_supported() {
  log_info "Checking NeoVim version..."
  if ! command -v nvim &>/dev/null; then
    log_info "NeoVim is not installed. Installing via dnf..."
    sudo dnf install -y neovim || true
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
    log_warn "Please upgrade NeoVim: sudo dnf upgrade -y neovim"
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
    sudo dnf install -y golang || true

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

# Fallback for `shfmt`: the vgaetera/extras COPR is the primary source, but COPR
# builds can lag new Fedora releases, so build it from source with the Go
# toolchain into ~/.local/bin (the same drop-in location used for hyprls).
install_shfmt() {
  if command -v shfmt >/dev/null 2>&1; then
    log_success "✓ shfmt already installed ($(shfmt --version 2>/dev/null || echo 'installed'))"
    return 0
  fi

  if ! command -v go >/dev/null 2>&1; then
    log_info "Installing Go toolchain (required to build shfmt)..."
    dnf_install_packages golang || true
  fi

  if ! command -v go >/dev/null 2>&1; then
    log_warn "⚠ Go compiler not found; skipping shfmt build"
    log_warn "  Install manually: sudo dnf install -y golang && go install mvdan.cc/sh/v3/cmd/shfmt@latest"
    FAILED_BUILD+=("shfmt")
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  log_info "Installing shfmt via go install..."
  if GOBIN="$HOME/.local/bin" go install mvdan.cc/sh/v3/cmd/shfmt@latest 2>&1 | tee /tmp/shfmt-build.log; then
    export PATH="$HOME/.local/bin:$PATH"
    log_success "✓ shfmt installed to $HOME/.local/bin"
  else
    log_warn "⚠ shfmt build failed (see /tmp/shfmt-build.log)"
    log_warn "  Install manually: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
    FAILED_BUILD+=("shfmt")
  fi
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies (Fedora)      ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Enabling COPR repositories..."
  sudo dnf copr enable -y relativesure/all-packages 2>/dev/null || true
  sudo dnf copr enable -y atim/lazygit 2>/dev/null || true
  sudo dnf copr enable -y yorickpeterse/stylua 2>/dev/null || true
  sudo dnf copr enable -y vgaetera/extras 2>/dev/null || true

  local dnf_pkgs=(
    git
    ripgrep
    fd
    curl
    jq
    "@development-tools"
    pkg-config
    tree-sitter-cli
    lua
    luarocks
    python3-devel
    python3-pip
    nodejs
    npm
    clang
    clang-tools-extra
    rust
    lua-language-server
    stylua
    shfmt
    lazygit
    bat
    wl-clipboard
  )

  # shfmt comes from the vgaetera/extras COPR enabled above. If that COPR has no
  # build for this release, the name is skipped instead of aborting the whole
  # transaction, and install_shfmt builds it from source below.
  dnf_install_packages "${dnf_pkgs[@]}" || true

  sudo dnf install -y luacheck 2>/dev/null || sudo dnf install -y lua-check 2>/dev/null || true

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

  # NPM packages
  install_npm_packages \
    bash-language-server \
    @johnnymorganz/stylua-bin \
    prettier \
    @fsouza/prettierd \
    vscode-langservers-extracted \
    neovim

  install_shfmt

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
    run_update_tasks "Fedora"
    exit 0
  fi

  if [ "$DEPS_ONLY" -eq 1 ]; then
    check_and_install_deps
    exit 0
  fi

  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Fedora Linux Installation                          ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  ensure_neovim_supported
  echo ""

  backup_neovim_config
  echo ""

  log_info "Step 1: Updating package manager database..."
  sudo dnf update -y || true

  check_and_install_deps

  echo ""
  sync_neovim_config

  echo ""
  configure_shell_path

  print_installation_summary
}

main "$@"
