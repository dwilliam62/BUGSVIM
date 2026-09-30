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

# ================================================================================================
# Resilient Package Installation
# ================================================================================================
# brew and rpm-ostree both resolve the entire argument list before installing
# anything, so a single unavailable name aborts the whole transaction. On Fedora
# Atomic that silently dropped every package whenever one name was missing
# (e.g. shfmt, which Fedora does not package).

brew_install_packages() {
  local installable=()
  local unavailable=()

  for pkg in "$@"; do
    if brew info --formula "$pkg" >/dev/null 2>&1; then
      installable+=("$pkg")
    else
      log_warn "○ $pkg (no Homebrew formula)"
      unavailable+=("$pkg")
    fi
  done

  if [ ${#installable[@]} -gt 0 ]; then
    brew install "${installable[@]}" || {
      FAILED_PACKAGES+=("${installable[@]}")
      log_warn "⚠ Some Homebrew packages failed to install"
    }
  fi

  if [ ${#unavailable[@]} -gt 0 ]; then
    FAILED_PACKAGES+=("${unavailable[@]}")
  fi
}

rpm_ostree_install_packages() {
  local pkgs=("$@")
  if [ ${#pkgs[@]} -eq 0 ]; then
    return 0
  fi

  local attempts=0
  while [ ${#pkgs[@]} -gt 0 ] && [ "$attempts" -lt 3 ]; do
    attempts=$((attempts + 1))

    local output
    if output="$(sudo rpm-ostree install -y "${pkgs[@]}" 2>&1)"; then
      log_success "✓ Layered: ${pkgs[*]}"
      return 0
    fi
    printf '%s\n' "$output" | tail -3

    # rpm-ostree has no --skip-unavailable equivalent: it reports unknown names
    # instead of skipping them. Parse those out, report them, and retry with the
    # remaining packages so one bad name cannot block the rest.
    local missing
    missing="$(printf '%s\n' "$output" |
      sed -nE 's/^.*(Packages? not found|No match for argument)[:[:space:]]*//p' |
      tr ',' '\n' | tr -d '[:blank:]\r' | sed 's/\.$//' | sort -u)"

    local remaining=()
    local dropped=0
    for pkg in "${pkgs[@]}"; do
      if [ -n "$missing" ] && printf '%s\n' "$missing" | grep -qxF -- "$pkg"; then
        log_warn "○ $pkg (not available in the enabled repositories)"
        FAILED_PACKAGES+=("$pkg")
        dropped=1
      else
        remaining+=("$pkg")
      fi
    done

    if [ "$dropped" -eq 0 ]; then
      log_warn "⚠ rpm-ostree layering failed for: ${pkgs[*]}"
      FAILED_PACKAGES+=("${pkgs[@]}")
      return 1
    fi

    pkgs=("${remaining[@]}")
  done
}

# Fedora Atomic images frequently ship no dnf copr plugin, but rpm-ostree reads
# the same repo files from /etc/yum.repos.d, so write one directly if needed.
enable_copr_repo() {
  local owner="$1"
  local project="$2"
  local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${owner}:${project}.repo"

  if [ -f "$repo_file" ]; then
    log_success "✓ COPR ${owner}/${project} already enabled"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1 && sudo dnf copr enable -y "${owner}/${project}" >/dev/null 2>&1; then
    log_success "✓ COPR ${owner}/${project} enabled"
    return 0
  fi

  log_info "Enabling COPR ${owner}/${project} via repo file..."
  if sudo tee "$repo_file" >/dev/null <<EOF
[copr:copr.fedorainfracloud.org:${owner}:${project}]
name=Copr repo for ${project} owned by ${owner}
baseurl=https://download.copr.fedorainfracloud.org/results/${owner}/${project}/fedora-\$releasever-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/${owner}/${project}/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
  then
    log_success "✓ COPR ${owner}/${project} enabled via repo file"
  else
    log_warn "⚠ Unable to enable COPR ${owner}/${project}"
  fi
}

# shfmt is not packaged by Fedora (it comes from the vgaetera/extras COPR on the
# rpm-ostree path), so keep a source build as a fallback.
install_shfmt() {
  if command -v shfmt >/dev/null 2>&1; then
    log_success "✓ shfmt already installed ($(shfmt --version 2>/dev/null || echo 'installed'))"
    return 0
  fi

  if [ "$USE_BREW" -eq 1 ]; then
    brew_install_packages shfmt
    if command -v shfmt >/dev/null 2>&1; then
      log_success "✓ shfmt installed via Homebrew"
      return 0
    fi

    if ! command -v go >/dev/null 2>&1; then
      log_info "Installing Go toolchain (required to build shfmt)..."
      brew_install_packages go
    fi
  fi

  # On the rpm-ostree path nothing that was layered is usable until the next
  # reboot, so layering a Go toolchain just to build shfmt would be wasted work.
  if ! command -v go >/dev/null 2>&1; then
    log_warn "⚠ Go compiler not found; skipping the shfmt source build"
    if [ "$USE_BREW" -eq 0 ]; then
      log_warn "  shfmt is layered from the vgaetera/extras COPR; reboot, then re-run 'bash install.sh -d' to verify."
    fi
    log_warn "  To build it manually: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
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
    brew_install_packages \
      git ripgrep fd curl jq pkg-config tree-sitter \
      gcc make automake autoconf \
      lua luarocks python node llvm rust \
      shfmt clang-format lazygit bat
  else
    log_info "Enabling COPR repositories..."
    enable_copr_repo relativesure all-packages
    enable_copr_repo atim lazygit
    enable_copr_repo vgaetera extras

    # tree-sitter-cli is the Fedora package name; shfmt comes from vgaetera/extras
    # and lua-language-server from relativesure/all-packages.
    rpm_ostree_install_packages \
      git ripgrep fd curl jq pkg-config tree-sitter-cli \
      gcc gcc-c++ make automake autoconf \
      lua luarocks lua-language-server python3-devel python3-pip nodejs npm \
      clang clang-tools-extra rust shfmt lazygit bat wl-clipboard || true

    log_warn "⚠ rpm-ostree layers only become available after a reboot, so packages layered just now may still show as missing below."
    log_warn "  Reboot, then re-run 'bash install.sh -d' to verify."
  fi

  install_shfmt

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
