#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Shared Installer Library
# ================================================================================================
# This file provides common utilities, CLI parsing, backup, npm management,
# and verification routines used by all bugsvim install scripts.
# ================================================================================================

# Strict mode
set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Error tracking arrays
FAILED_PACKAGES=()
FAILED_NPM=()
FAILED_PYTHON=()
FAILED_BUILD=()
FAILED_AUR=()
MISSING=0

# Operation flags
FORCE_REINSTALL=0
UPDATE_ONLY=0
DEPS_ONLY=0
DEBUG=0
SPECIFIED_DISTRO=""

# Supported distribution map
SUPPORTED_DISTROS=(
  "arch:Arch Linux, EndeavourOS, Manjaro, CachyOS, Artix, Garuda"
  "debian:Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin OS, Elementary OS, Kali"
  "fedora:Fedora, Nobara, RHEL, CentOS Stream, AlmaLinux, Rocky Linux"
  "gentoo:Gentoo Linux, Funtoo"
  "opensuse:openSUSE Tumbleweed, Leap, SUSE Linux Enterprise"
  "alpine:Alpine Linux"
  "bazzite:Bazzite, Fedora Silverblue/Kinoite, Universal Blue"
  "freebsd:FreeBSD"
  "openbsd:OpenBSD"
)

# ================================================================================================
# Logging and Debug Helpers
# ================================================================================================

log_debug() {
  if [ "$DEBUG" -eq 1 ]; then
    echo -e "${MAGENTA}[DEBUG]${NC} $*" >&2
  fi
}

log_info() {
  echo -e "${BLUE}$*${NC}"
}

log_success() {
  echo -e "${GREEN}$*${NC}"
}

log_warn() {
  echo -e "${YELLOW}$*${NC}"
}

log_error() {
  echo -e "${RED}$*${NC}"
}

# ================================================================================================
# Privilege Helper
# ================================================================================================

run_as_root() {
  log_debug "Executing privileged command: $*"
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    log_error "Error: Root privileges required via 'sudo' or 'doas'."
    exit 1
  fi
}

# ================================================================================================
# CLI Argument Parsing & Help
# ================================================================================================

list_supported_distros() {
  echo -e "${BLUE}Supported Distributions for bugsvim:${NC}"
  echo ""
  printf "  %-12s  %s\n" "KEY" "MATCHED DISTRIBUTIONS / DERIVATIVES"
  printf "  %-12s  %s\n" "---" "------------------------------------"
  for entry in "${SUPPORTED_DISTROS[@]}"; do
    local key="${entry%%:*}"
    local desc="${entry#*:}"
    printf "  ${GREEN}%-12s${NC}  %s\n" "$key" "$desc"
  done
  echo ""
  echo -e "You can pass ${CYAN}--distro <key>${NC} (e.g. ${CYAN}./install.sh --distro debian${NC}) to override auto-detection."
}

print_common_usage() {
  local script_name
  script_name="$(basename "$0")"
  cat <<EOF
Usage: $script_name [options]

Options:
  -f, --force           Force rebuild/reinstall of optional packages
  -u, --update          Run update tasks (check/install tree-sitter-cli, clean legacy caches, sync config)
  -d, --deps            Check for all dependencies and install missing ones
  -D, --distro <name>   Override distribution detection (e.g. debian, arch, fedora, gentoo)
      --list-distros    List all supported distribution keys and derivatives
      --debug           Enable verbose debug logging
  -h, --help            Show this help message

Examples:
  ./install.sh                      # Auto-detects OS and runs full install
  ./install.sh --distro debian      # Run Debian/Ubuntu installer on derivative OS (e.g. Zorin)
  ./install.sh -u                   # Run update pipeline
  ./install.sh -d                   # Check and install missing dependencies
  ./install.sh --list-distros       # Show supported distributions
EOF
}

parse_common_args() {
  log_debug "Parsing CLI arguments: $*"
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -f | --force)
      FORCE_REINSTALL=1
      shift
      ;;
    -u | --update)
      UPDATE_ONLY=1
      shift
      ;;
    -d | --deps)
      DEPS_ONLY=1
      shift
      ;;
    --debug)
      DEBUG=1
      log_debug "Debug mode enabled"
      shift
      ;;
    --list-distros)
      list_supported_distros
      exit 0
      ;;
    -D | --distro)
      if [ -n "${2:-}" ] && [[ ! "$2" =~ ^- ]]; then
        SPECIFIED_DISTRO="$2"
        shift 2
      else
        log_error "Error: --distro requires a distribution argument."
        exit 1
      fi
      ;;
    --distro=*)
      SPECIFIED_DISTRO="${1#*=}"
      shift
      ;;
    -h | --help)
      print_common_usage
      exit 0
      ;;
    *)
      log_warn "Unknown option: $1"
      print_common_usage
      exit 1
      ;;
    esac
  done
}

# ================================================================================================
# NPM Setup & Management
# ================================================================================================

setup_npm_prefix() {
  NPM_PREFIX="${NPM_PREFIX:-$HOME/.npm-global}"
  log_debug "Setting up npm prefix at: $NPM_PREFIX"
  if command -v npm &>/dev/null; then
    mkdir -p "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX" --location=user 2>/dev/null || npm config set prefix "$NPM_PREFIX" 2>/dev/null || true
    export NPM_CONFIG_PREFIX="$NPM_PREFIX"
    export PATH="$NPM_PREFIX/bin:$PATH"
    log_debug "NPM prefix configured and added to PATH: $PATH"
  fi
}

npm_pkg_installed() {
  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi
  local prefix="${NPM_PREFIX:-$HOME/.npm-global}"
  npm list -g --prefix "$prefix" "$1" >/dev/null 2>&1 || npm list -g "$1" >/dev/null 2>&1
}

# Executables provided by npm packages. Distros may ship the same tooling as
# native packages (e.g. Arch installs bash-language-server via pacman), so
# verification must not assume npm is the only valid source.
npm_pkg_binaries() {
  case "$1" in
  "@fsouza/prettierd") printf '%s\n' prettierd ;;
  "vscode-langservers-extracted")
    printf '%s\n' vscode-html-language-server vscode-css-language-server \
      vscode-json-language-server vscode-eslint-language-server
    ;;
  "bash-language-server") printf '%s\n' bash-language-server ;;
  "@johnnymorganz/stylua-bin") printf '%s\n' stylua ;;
  "pyright") printf '%s\n' pyright pyright-langserver ;;
  "neovim") ;; # node host library, provides no executable
  *) printf '%s\n' "$1" ;;
  esac
}

npm_pkg_binary_available() {
  local bin
  while read -r bin; do
    [ -n "$bin" ] || continue
    if command -v "$bin" >/dev/null 2>&1; then
      return 0
    fi
  done < <(npm_pkg_binaries "$1")
  return 1
}

# Echoes how a package is provided: 'npm', 'system', or 'none'.
detect_pkg_source() {
  if npm_pkg_installed "$1"; then
    printf 'npm\n'
  elif npm_pkg_binary_available "$1"; then
    printf 'system\n'
  else
    printf 'none\n'
  fi
}

install_npm_packages() {
  setup_npm_prefix
  if ! command -v npm &>/dev/null; then
    log_warn "npm not available; skipping npm packages: $*"
    for pkg in "$@"; do
      FAILED_NPM+=("$pkg")
    done
    return 1
  fi

  local pkgs=("$@")
  for pkg in "${pkgs[@]}"; do
    if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed "$pkg"; then
      log_info "Installing npm package: ${pkg}..."
      if npm install -g --prefix "$NPM_PREFIX" "$pkg"; then
        log_success "✓ npm package $pkg installed successfully"
      else
        log_error "✗ Failed to install npm package: $pkg"
        FAILED_NPM+=("$pkg")
      fi
    else
      log_success "✓ npm package $pkg already installed"
    fi
  done
}

# ================================================================================================
# NeoVim Semver & Support Checks
# ================================================================================================

parse_nvim_semver() {
  local ver="$1"
  local a b c
  ver="${ver#v}"
  IFS='.' read -r a b c <<<"$ver"
  a="${a:-0}"
  b="${b:-0}"
  c="${c:-0}"

  if [[ "$a" -eq 0 ]]; then
    printf '%s %s %s\n' "$b" "$c" "0"
  else
    printf '%s %s %s\n' "$a" "$b" "$c"
  fi
}

# ================================================================================================
# Update Tasks Pipeline
# ================================================================================================

clean_legacy_treesitter() {
  log_info "Checking for legacy nvim-treesitter cache..."
  local ts_dir="${HOME}/.local/share/nvim/lazy/nvim-treesitter"
  if [ -d "$ts_dir" ]; then
    log_warn "Removing legacy nvim-treesitter cache (${ts_dir}) for clean main branch migration..."
    rm -rf "$ts_dir"
    log_success "✓ Legacy nvim-treesitter cache removed"
  else
    log_success "✓ No legacy nvim-treesitter directory found"
  fi
}

update_treesitter_cli() {
  log_info "Checking tree-sitter CLI..."
  if ! command -v tree-sitter >/dev/null 2>&1; then
    log_warn "tree-sitter CLI not found. Installing..."
    if command -v cargo >/dev/null 2>&1; then
      log_info "Installing tree-sitter-cli via cargo..."
      if cargo install tree-sitter-cli --root "${HOME}/.local"; then
        log_success "✓ tree-sitter-cli installed via cargo"
        export PATH="${HOME}/.local/bin:$PATH"
        return 0
      fi
    fi
    log_warn "○ Unable to install tree-sitter-cli automatically. Please install via system package or cargo."
  else
    log_success "✓ tree-sitter CLI available: $(tree-sitter --version 2>/dev/null || echo 'installed')"
  fi
}

sync_neovim_config() {
  log_info "Syncing bugsvim config to ~/.config/nvim..."
  local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  if [ ! -d "${repo_root}/nvim" ]; then
    log_error "✗ Cannot find 'nvim' source directory in ${repo_root}"
    return 1
  fi
  mkdir -p "${HOME}/.config/nvim"
  cp -r "${repo_root}/nvim/"* "${HOME}/.config/nvim/"
  log_success "✓ bugsvim config updated in ~/.config/nvim"
}

run_update_tasks() {
  local distro_title="${1:-Standard}"
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - ${distro_title} Update Tasks                       ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  clean_legacy_treesitter
  echo ""
  update_treesitter_cli
  echo ""
  sync_neovim_config
  echo ""
  log_success "✓ All update tasks completed successfully!"
  echo "Next steps: Launch 'nvim' and run ':Lazy sync' or ':TSUpdate' if needed."
}

# ================================================================================================
# Backup Existing NeoVim Configuration
# ================================================================================================

backup_neovim_config() {
  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M%S")
  local backup_dir="${HOME}/.config/neovim-backup-${timestamp}"
  local has_config=false

  log_info "Checking for existing NeoVim configuration..."

  if [ -d "${HOME}/.config/nvim" ] || [ -d "${HOME}/.local/share/nvim" ] || [ -d "${HOME}/.local/state/nvim" ]; then
    has_config=true
  fi

  if [ "$has_config" = true ]; then
    log_warn "Found existing NeoVim configuration"
    read -p "Backup existing config? (y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mkdir -p "$backup_dir"
      log_info "Creating backup in: $backup_dir"

      [ -d "${HOME}/.config/nvim" ] && cp -r "${HOME}/.config/nvim" "$backup_dir/.config-nvim"
      [ -d "${HOME}/.local/share/nvim" ] && cp -r "${HOME}/.local/share/nvim" "$backup_dir/.local-share-nvim"
      [ -d "${HOME}/.local/state/nvim" ] && cp -r "${HOME}/.local/state/nvim" "$backup_dir/.local-state-nvim"

      log_success "✓ Backup created: $backup_dir"
    else
      log_warn "Skipping backup"
    fi

    log_info "Removing existing NeoVim config and state..."
    rm -rf "${HOME}/.config/nvim"
    rm -rf "${HOME}/.local/share/nvim"
    rm -rf "${HOME}/.local/state/nvim"
    log_success "✓ Existing config and state removed"
  else
    log_success "✓ No existing NeoVim configuration found"
  fi
}

# ================================================================================================
# Shell Configuration
# ================================================================================================

configure_shell_path() {
  log_info "Configuring shell PATH for user npm and local binaries..."
  local current_shell
  current_shell="$(basename "${SHELL:-bash}")"
  local shell_config=""
  local npm_path_line='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'

  case "$current_shell" in
  zsh)
    shell_config="${HOME}/.zshrc"
    npm_path_line='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
    ;;
  bash)
    shell_config="${HOME}/.bashrc"
    npm_path_line='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
    ;;
  fish)
    shell_config="${HOME}/.config/fish/config.fish"
    npm_path_line='set -gx PATH $HOME/.npm-global/bin $HOME/.local/bin $PATH'
    ;;
  *)
    shell_config="${HOME}/.${current_shell}rc"
    npm_path_line='export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
    log_warn "Note: Detected shell '$current_shell' - using $shell_config"
    ;;
  esac

  if [ -f "$shell_config" ]; then
    if ! grep -q "npm-global" "$shell_config"; then
      echo "$npm_path_line" >>"$shell_config"
      log_success "✓ Added npm and local PATH to $shell_config"
    else
      log_success "✓ npm PATH already in $shell_config"
    fi
  else
    log_warn "Note: Shell config file not found at $shell_config"
    echo -e "Please add the following line to your shell profile manually:\n  $npm_path_line"
  fi
}

# ================================================================================================
# Verification Helpers
# ================================================================================================

verify_installation() {
  MISSING=0

  echo "Checking core tools:"
  for cmd in nvim git rg fd curl clang; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${RED}✗${NC} $cmd (missing)"
      MISSING=1
    fi
  done

  echo ""
  echo "Checking formatters and linters:"
  for cmd in stylua luacheck shfmt clang-format prettier; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${YELLOW}○${NC} $cmd (not found, but may be optional)"
    fi
  done

  echo ""
  echo "Checking language server packages:"
  if ! command -v npm &>/dev/null; then
    echo -e "  ${YELLOW}○${NC} npm not available (checking for system-provided binaries only)"
  fi
  for pkg in "@fsouza/prettierd" "vscode-langservers-extracted" "bash-language-server"; do
    case "$(detect_pkg_source "$pkg")" in
    npm)
      echo -e "  ${GREEN}✓${NC} $pkg (npm)"
      ;;
    system)
      echo -e "  ${GREEN}✓${NC} $pkg (system package)"
      ;;
    *)
      echo -e "  ${RED}✗${NC} $pkg (missing)"
      MISSING=1
      ;;
    esac
  done

  echo ""
  echo "Checking tree-sitter CLI:"
  if command -v tree-sitter &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} tree-sitter ($(tree-sitter --version 2>/dev/null || echo 'installed'))"
  else
    echo -e "  ${YELLOW}○${NC} tree-sitter (missing, recommended for Treesitter parser compilation)"
  fi
}

# ================================================================================================
# Installation Summary
# ================================================================================================

print_installation_summary() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Installation Summary                                         ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install packages:${NC}"
    for pkg in "${FAILED_PACKAGES[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_NPM[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install npm packages:${NC}"
    for pkg in "${FAILED_NPM[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_PYTHON[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install Python packages:${NC}"
    for pkg in "${FAILED_PYTHON[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_AUR[@]} -gt 0 ]; then
    echo -e "${RED}Failed to install AUR packages:${NC}"
    for pkg in "${FAILED_AUR[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  if [ ${#FAILED_BUILD[@]} -gt 0 ]; then
    echo -e "${RED}Failed to build/install tools:${NC}"
    for pkg in "${FAILED_BUILD[@]}"; do
      echo "  • $pkg"
    done
    echo ""
  fi

  local total_failures=$((${#FAILED_PACKAGES[@]} + ${#FAILED_NPM[@]} + ${#FAILED_PYTHON[@]} + ${#FAILED_AUR[@]} + ${#FAILED_BUILD[@]}))

  if [ $MISSING -eq 0 ] && [ "$total_failures" -eq 0 ]; then
    log_success "✓ Installation completed successfully!"
  else
    log_warn "⚠ Installation completed with some optional components needing attention (see above)."
    log_warn "However, bugsvim config has been installed to ~/.config/nvim."
  fi

  echo ""
  echo "Next steps:"
  echo "  1. Reload your shell profile or restart your terminal"
  echo "  2. Launch neovim: nvim"
  echo "  3. Plugins will auto-install on first launch (lazy.nvim)"
  echo "  4. Treesitter parsers will auto-install (nvim-treesitter)"
  echo "  5. Verify installation inside NeoVim: :checkhealth"
  echo ""
  echo "See POST-INSTALL.md for additional setup and troubleshooting."
}
