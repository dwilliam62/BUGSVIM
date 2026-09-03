#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for Gentoo Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Gentoo Linux
# ================================================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error tracking
FAILED_PACKAGES=()
FAILED_NPM=()
FAILED_PYTHON=()
FAILED_BUILD=()

FORCE_REINSTALL=0
UPDATE_ONLY=0

usage() {
  cat <<'EOF'
Usage: install-gentoo.sh [options]

Options:
  -f, --force    Force rebuild/reinstall of optional packages
  -u, --update   Run update tasks (check/install tree-sitter-cli, clean legacy caches, sync config)
  -h, --help     Show this help message
EOF
}

for arg in "$@"; do
  case "$arg" in
  -f | --force) FORCE_REINSTALL=1 ;;
  -u | --update) UPDATE_ONLY=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $arg"
    usage
    exit 1
    ;;
  esac
done

# ================================================================================================
# Update tasks pipeline (Modular - add new tasks to UPDATE_TASKS array)
# ================================================================================================
update_treesitter_cli() {
  echo -e "${BLUE}Checking tree-sitter CLI...${NC}"
  if ! command -v tree-sitter >/dev/null 2>&1; then
    echo -e "${YELLOW}tree-sitter CLI not found. Installing...${NC}"
    if sudo emerge --noreplace dev-util/tree-sitter-cli 2>/dev/null; then
      echo -e "${GREEN}✓ tree-sitter-cli installed via Portage${NC}"
    elif command -v cargo >/dev/null 2>&1; then
      echo -e "${BLUE}Installing tree-sitter-cli via cargo...${NC}"
      cargo install tree-sitter-cli --root "${HOME}/.local" && echo -e "${GREEN}✓ tree-sitter-cli installed via cargo${NC}"
    else
      echo -e "${RED}✗ Unable to install tree-sitter-cli (install dev-util/tree-sitter-cli or cargo)${NC}"
    fi
  else
    echo -e "${GREEN}✓ tree-sitter CLI available: $(tree-sitter --version 2>/dev/null || echo 'installed')${NC}"
  fi
}

clean_legacy_treesitter() {
  echo -e "${BLUE}Checking for legacy nvim-treesitter cache...${NC}"
  local ts_dir="${HOME}/.local/share/nvim/lazy/nvim-treesitter"
  if [ -d "$ts_dir" ]; then
    echo -e "${YELLOW}Removing legacy nvim-treesitter cache (${ts_dir}) for clean main branch migration...${NC}"
    rm -rf "$ts_dir"
    echo -e "${GREEN}✓ Legacy nvim-treesitter cache removed${NC}"
  else
    echo -e "${GREEN}✓ No legacy nvim-treesitter directory found${NC}"
  fi
}

sync_neovim_config() {
  echo -e "${BLUE}Syncing bugsvim config to ~/.config/nvim...${NC}"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  mkdir -p "${HOME}/.config/nvim"
  cp -r "${script_dir}/nvim/"* "${HOME}/.config/nvim/"
  echo -e "${GREEN}✓ bugsvim config updated in ~/.config/nvim${NC}"
}

# Modular update tasks list — easily add future update tasks here
UPDATE_TASKS=(
  clean_legacy_treesitter
  update_treesitter_cli
  sync_neovim_config
)

run_update_tasks() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Gentoo Linux Update Tasks                          ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  for task in "${UPDATE_TASKS[@]}"; do
    "$task"
    echo ""
  done
  echo -e "${GREEN}✓ All update tasks completed successfully!${NC}"
  echo "Next steps: Launch 'nvim' and run ':Lazy sync' or ':TSUpdate' if needed."
}

if [ "$UPDATE_ONLY" -eq 1 ]; then
  run_update_tasks
  exit 0
fi

# ================================================================================================
# hyprls helpers
# ================================================================================================
hyprls_installed() {
  command -v hyprls >/dev/null 2>&1
}

hyprls_version() {
  hyprls </dev/null 2>&1 | sed -n 's/.*hyprls@\([^/]*\).*/\1/p' | head -1
}

npm_pkg_installed() {
  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi
  local prefix="${NPM_PREFIX:-$HOME/.npm-global}"
  npm list -g --prefix "$prefix" "$1" >/dev/null 2>&1
}

# ================================================================================================
# repo helpers
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
    echo -e "${YELLOW}Note: eselect-repository not available, installing...${NC}"
    sudo emerge --noreplace app-eselect/eselect-repository || return 1
  fi
}

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

discover_neovim_11_atom() {
  local ebuild_dir="/var/db/repos/gentoo/app-editors/neovim"
  local version=""
  local latest_011 latest_11

  if [[ -d "$ebuild_dir" ]]; then
    latest_011="$(find "$ebuild_dir" -maxdepth 1 -type f -name 'neovim-0.11*.ebuild' -printf '%f\n' 2>/dev/null | sed -E 's/^neovim-(.+)\.ebuild$/\1/' | sort -V | tail -n1)"
    latest_11="$(find "$ebuild_dir" -maxdepth 1 -type f -name 'neovim-11*.ebuild' -printf '%f\n' 2>/dev/null | sed -E 's/^neovim-(.+)\.ebuild$/\1/' | sort -V | tail -n1)"
    version="${latest_011:-$latest_11}"
  fi

  if [[ -n "$version" ]]; then
    printf '=app-editors/neovim-%s\n' "$version"
    return 0
  fi

  printf 'app-editors/neovim\n'
  return 0
}

ensure_neovim_supported() {
  local nvim_version="" major minor patch target_atom
  local needs_install=0
  local reason=""

  echo -e "${BLUE}Checking NeoVim version...${NC}"
  if command -v nvim >/dev/null 2>&1; then
    nvim_version="$(nvim --version | head -1 | grep -oP 'NVIM v\K[^\s]+' || true)"
    if [[ -z "$nvim_version" ]]; then
      needs_install=1
      reason="unable to parse installed NeoVim version"
    else
      read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
      if [[ "$major" -ge 10 ]]; then
        echo -e "${GREEN}✓ NeoVim version: ${nvim_version} (supported)${NC}"
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
    echo -e "${YELLOW}Note: ${reason}${NC}"
    target_atom="app-editors/neovim"
    echo -e "${BLUE}Installing supported NeoVim release (${target_atom})...${NC}"
    if ! sudo emerge --ask=n --oneshot --autounmask-write --autounmask-continue --binpkg-respect-use=y "$target_atom"; then
      echo -e "${RED}✗ Failed to install ${target_atom}${NC}"
      echo -e "${RED}Please install NeoVim 0.10+ manually and rerun this script.${NC}"
      exit 1
    fi
  fi

  nvim_version="$(nvim --version | head -1 | grep -oP 'NVIM v\K[^\s]+' || true)"
  if [[ -z "$nvim_version" ]]; then
    echo -e "${RED}✗ Unable to verify NeoVim version after installation${NC}"
    exit 1
  fi
  read -r major minor patch <<<"$(parse_nvim_semver "$nvim_version")"
  if [[ "$major" -lt 10 ]]; then
    echo -e "${RED}✗ NeoVim 0.10+ is required, but found: ${nvim_version}${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ NeoVim version: ${nvim_version} (supported)${NC}"
}

enable_repo() {
  local repo="$1"
  local sync_type="${2:-}"
  local sync_uri="${3:-}"
  ensure_eselect_repository || return 1

  if repo_enabled "$repo"; then
    echo -e "${GREEN}✓ ${repo} repo already enabled${NC}"
    return 0
  fi

  if ! repo_known "$repo"; then
    if [ -n "$sync_type" ] && [ -n "$sync_uri" ]; then
      echo -e "${YELLOW}Repo '${repo}' not in eselect list; adding via '${sync_type}'...${NC}"
      sudo eselect repository add "$repo" "$sync_type" "$sync_uri" || return 1
    else
      echo -e "${YELLOW}Warning: repo '${repo}' not found in eselect list${NC}"
      return 1
    fi
  fi

  echo -e "${BLUE}Enabling repo: ${repo}${NC}"
  sudo eselect repository enable "$repo" || return 1
  sudo emaint sync -r "$repo" || sudo emerge --sync || true
  return 0
}

# ================================================================================================
# nix helpers
# ================================================================================================
install_nix() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi
  echo -e "${BLUE}Installing Nix package manager...${NC}"
  local url="${NIX_INSTALL_URL:-https://nixos.org/nix/install}"
  local flags="${NIX_INSTALL_FLAGS:---daemon --yes}"
  if curl -fsSL "$url" | sudo sh -s -- $flags; then
    if [ -f /etc/profile.d/nix.sh ]; then
      # shellcheck disable=SC1091
      . /etc/profile.d/nix.sh
    fi
    return 0
  fi
  echo -e "${YELLOW}Warning: Nix install failed${NC}"
  return 1
}

# ================================================================================================
# Backup existing NeoVim configuration
# ================================================================================================
backup_neovim_config() {
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local backup_dir="${HOME}/.config/neovim-backup-${timestamp}"
  local has_config=false

  echo -e "${BLUE}Checking for existing NeoVim configuration...${NC}"

  # Check each config location
  if [ -d "${HOME}/.config/nvim" ] || [ -d "${HOME}/.local/share/nvim" ] || [ -d "${HOME}/.local/state/nvim" ]; then
    has_config=true
  fi

  if [ "$has_config" = true ]; then
    echo -e "${YELLOW}Found existing NeoVim configuration${NC}"
    read -p "Backup existing config? (y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mkdir -p "$backup_dir"
      echo -e "${BLUE}Creating backup in: $backup_dir${NC}"

      [ -d "${HOME}/.config/nvim" ] && cp -r "${HOME}/.config/nvim" "$backup_dir/.config-nvim"
      [ -d "${HOME}/.local/share/nvim" ] && cp -r "${HOME}/.local/share/nvim" "$backup_dir/.local-share-nvim"
      [ -d "${HOME}/.local/state/nvim" ] && cp -r "${HOME}/.local/state/nvim" "$backup_dir/.local-state-nvim"

      echo -e "${GREEN}✓ Backup created: $backup_dir${NC}"
    else
      echo -e "${YELLOW}Skipping backup${NC}"
    fi

    # Remove existing config regardless of backup choice
    echo -e "${BLUE}Removing existing NeoVim config and state...${NC}"
    rm -rf "${HOME}/.config/nvim"
    rm -rf "${HOME}/.local/share/nvim"
    rm -rf "${HOME}/.local/state/nvim"
    echo -e "${GREEN}✓ Existing config and state removed${NC}"
  else
    echo -e "${GREEN}✓ No existing NeoVim configuration found${NC}"
  fi
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   bugsvim - Gentoo Linux Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

ensure_neovim_supported

echo ""

# Backup existing config
backup_neovim_config
echo ""

# Check if running on Gentoo
if ! grep -q "Gentoo" /etc/os-release 2>/dev/null; then
  echo -e "${YELLOW}Warning: This script is optimized for Gentoo Linux.${NC}"
  echo -e "${YELLOW}Detected: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)${NC}"
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Get the script directory before any cd operations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ================================================================================================
# Helper function to check if packages are installed
# ================================================================================================
check_and_install_packages() {
  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! qlist -I "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -gt 0 ]; then
    echo -e "${BLUE}Installing missing packages: ${to_install[*]}${NC}"
    sudo emerge --noreplace "${to_install[@]}"
  else
    echo -e "${GREEN}✓ All packages already installed${NC}"
  fi
}

echo -e "${BLUE}Step 1: Syncing package repository...${NC}"
sudo emerge --sync || true

echo -e "${BLUE}Step 2: Installing core dependencies...${NC}"
check_and_install_packages \
  dev-vcs/git \
  sys-apps/ripgrep \
  sys-apps/fd \
  net-misc/curl \
  app-misc/jq \
  sys-devel/gcc \
  dev-ruby/pkg-config \
  dev-util/tree-sitter-cli || true
update_treesitter_cli

echo -e "${BLUE}Step 3: Installing language servers and development tools...${NC}"
check_and_install_packages \
  dev-lang/lua \
  dev-lang/python \
  net-libs/nodejs
# llvm-core/clang  # disabled for now: C/C++ toolchain not needed

# Rust installation disabled for now (not needed)

echo -e "${BLUE}Step 3b: Setting up npm for global installs...${NC}"
NPM_PREFIX="${NPM_PREFIX:-$HOME/.npm-global}"
if ! command -v npm &>/dev/null; then
  echo -e "${RED}✗${NC} npm not found"
  echo -e "${YELLOW}Note: npm is controlled by the 'npm' USE flag for net-libs/nodejs${NC}"
  read -p "Enable npm USE flag for net-libs/nodejs now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "net-libs/nodejs npm" | sudo tee -a /etc/portage/package.use/nodejs >/dev/null
    sudo emerge --update --newuse net-libs/nodejs || true
  fi
  if ! command -v npm &>/dev/null; then
    echo -e "${RED}✗${NC} npm still not available - skipping npm configuration"
    FAILED_PACKAGES+=("npm")
  fi
else
  # Configure npm to use user directory instead of global (avoids permission issues)
  mkdir -p "$NPM_PREFIX"
  npm config set prefix "$NPM_PREFIX" --location=user 2>/dev/null || npm config set prefix "$NPM_PREFIX" 2>/dev/null || true
  export NPM_CONFIG_PREFIX="$NPM_PREFIX"
  export PATH="$NPM_PREFIX/bin:$PATH"
  echo -e "${GREEN}✓ npm configured for user installs${NC}"
fi

echo -e "${BLUE}Step 4: Installing formatters...${NC}"

# stylua - try Portage first, then GURU overlay
echo -e "${BLUE}  Installing stylua (Lua formatter)...${NC}"
if command -v stylua &>/dev/null; then
  echo -e "${GREEN}✓ stylua already installed${NC}"
elif sudo emerge --noreplace dev-util/stylua; then
  echo -e "${GREEN}✓ stylua installed${NC}"
else
  if enable_repo "guru"; then
    sudo emerge --noreplace dev-util/stylua && {
      echo -e "${GREEN}✓ stylua installed (GURU)${NC}"
    } || true
  fi
  echo -e "${YELLOW}Warning: stylua install failed${NC}"
fi
# shfmt - provided by dev-util/sh (includes shfmt)
# shfmt - available in app-shells/shfmt
echo -e "${BLUE}  Installing shfmt (Shell formatter)...${NC}"
if command -v shfmt &>/dev/null; then
  echo -e "${GREEN}✓ shfmt already installed${NC}"
elif sudo emerge --noreplace dev-util/sh; then
  echo -e "${GREEN}✓ shfmt installed${NC}"
else
  echo -e "${YELLOW}Warning: shfmt not available - will install via npm${NC}"
  if command -v npm &>/dev/null; then
    if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed shfmt; then
      npm install -g --prefix "$NPM_PREFIX" shfmt || FAILED_NPM+=("shfmt")
    else
      echo -e "${GREEN}✓ shfmt already installed${NC}"
    fi
  else
    echo -e "${RED}✗${NC} npm not available - cannot install shfmt via npm"
    FAILED_NPM+=("shfmt")
  fi
fi

# clang-format - included with clang
echo -e "${BLUE}  Verifying clang-format (C/C++ formatter)...${NC}"
if command -v clang-format &>/dev/null; then
  echo -e "${GREEN}✓ clang-format available${NC}"
else
  echo -e "${YELLOW}Warning: clang-format not found${NC}"
fi

# prettier - install via npm
echo -e "${BLUE}  Installing prettier (Web formatter)...${NC}"
if command -v npm &>/dev/null; then
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed prettier; then
    npm install -g --prefix "$NPM_PREFIX" prettier || FAILED_NPM+=("prettier")
  else
    echo -e "${GREEN}✓ prettier already installed${NC}"
  fi
else
  echo -e "${RED}✗${NC} npm not available - cannot install prettier"
  FAILED_NPM+=("prettier")
fi

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
check_and_install_packages \
  dev-vcs/lazygit \
  sys-apps/bat \
  gui-apps/wl-clipboard || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
if command -v npm &>/dev/null; then
  echo -e "${BLUE}  Installing prettierd (Prettier daemon)...${NC}"
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed @fsouza/prettierd; then
    npm install -g --prefix "$NPM_PREFIX" @fsouza/prettierd || FAILED_NPM+=("@fsouza/prettierd")
  else
    echo -e "${GREEN}✓ @fsouza/prettierd already installed${NC}"
  fi

  echo -e "${BLUE}  Installing vscode-langservers...${NC}"
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed vscode-langservers-extracted; then
    npm install -g --prefix "$NPM_PREFIX" vscode-langservers-extracted || FAILED_NPM+=("vscode-langservers-extracted")
  else
    echo -e "${GREEN}✓ vscode-langservers-extracted already installed${NC}"
  fi

  echo -e "${BLUE}  Installing bash-language-server...${NC}"
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed bash-language-server; then
    npm install -g --prefix "$NPM_PREFIX" bash-language-server || FAILED_NPM+=("bash-language-server")
  else
    echo -e "${GREEN}✓ bash-language-server already installed${NC}"
  fi
else
  echo -e "${RED}✗${NC} npm not available - skipping npm global packages"
  FAILED_NPM+=("@fsouza/prettierd" "vscode-langservers-extracted" "bash-language-server")
fi

echo -e "${BLUE}Step 7: Installing Python packages (ruff, pyright)...${NC}"
PYTHON_INSTALLED=0
if [ "$FORCE_REINSTALL" -ne 1 ] && command -v ruff >/dev/null 2>&1 && command -v pyright >/dev/null 2>&1; then
  PYTHON_INSTALLED=1
else
  # Prefer Portage for ruff
  if ! command -v ruff >/dev/null 2>&1; then
    if sudo emerge --noreplace dev-util/ruff; then
      true
    fi
  fi

  # Try Portage for pyright via overlay (waffle-builds)
  if ! command -v pyright >/dev/null 2>&1; then
    WAFFLE_BUILDS_URI="${WAFFLE_BUILDS_URI:-https://github.com/FlyingWaffleDev/waffle-builds}"
    if enable_repo "waffle-builds" "git" "$WAFFLE_BUILDS_URI"; then
      sudo emerge --noreplace dev-python/pyright || true
    fi
  fi
  # Fallback to npm for pyright if still missing
  if ! command -v pyright >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    npm install -g --prefix "$NPM_PREFIX" pyright || FAILED_NPM+=("pyright")
  fi

  if command -v ruff >/dev/null 2>&1 && command -v pyright >/dev/null 2>&1; then
    PYTHON_INSTALLED=1
  elif command -v pip3 &>/dev/null; then
    pip3 install --user ruff pyright 2>/dev/null && PYTHON_INSTALLED=1
  fi
fi

if [ $PYTHON_INSTALLED -eq 0 ] && command -v python3 &>/dev/null; then
  python3 -m ensurepip --user 2>/dev/null || true
  python3 -m pip install --user ruff pyright 2>/dev/null && PYTHON_INSTALLED=1
fi

if [ $PYTHON_INSTALLED -eq 0 ]; then
  FAILED_PYTHON+=("ruff" "pyright")
  echo -e "${YELLOW}Warning: Python packages install failed${NC}"
fi

echo -e "${BLUE}Step 8: Installing Lua Language Server...${NC}"
echo -e "${YELLOW}Note: lua-language-server may need to be installed from source${NC}"
if qlist -I dev-util/lua-language-server &>/dev/null; then
  echo -e "${GREEN}✓ lua-language-server already installed${NC}"
elif sudo emerge --noreplace dev-util/lua-language-server 2>/dev/null; then
  echo -e "${GREEN}✓ lua-language-server installed${NC}"
else
  echo -e "${YELLOW}⚠ lua-language-server not available in main repo${NC}"
  if enable_repo "guru"; then
    sudo emerge --noreplace dev-util/lua-language-server 2>/dev/null && {
      echo -e "${GREEN}✓ lua-language-server installed (GURU)${NC}"
    } || true
  else
    echo -e "${YELLOW}Install from: https://github.com/LuaLS/lua-language-server/releases${NC}"
    echo -e "${YELLOW}Or add GURU overlay: eselect repository enable guru && emaint sync -r guru${NC}"
  fi
  FAILED_BUILD+=("lua-language-server")
fi

echo -e "${BLUE}Step 9: Installing Nil (Nix LSP)...${NC}"
if qlist -I dev-lang/nil &>/dev/null; then
  echo -e "${GREEN}✓ nil already installed${NC}"
else
  NIL_INSTALLED=0
  NIX_BIN=""
  if [ -n "${NIX_BIN_OVERRIDE:-}" ] && [ -x "${NIX_BIN_OVERRIDE:-}" ]; then
    NIX_BIN="$NIX_BIN_OVERRIDE"
  elif command -v nix >/dev/null 2>&1; then
    NIX_BIN="$(command -v nix)"
  elif [ -x /nix/var/nix/profiles/default/bin/nix ]; then
    NIX_BIN="/nix/var/nix/profiles/default/bin/nix"
  elif [ -x "$HOME/.nix-profile/bin/nix" ]; then
    NIX_BIN="$HOME/.nix-profile/bin/nix"
  elif [ -x /run/current-system/sw/bin/nix ]; then
    NIX_BIN="/run/current-system/sw/bin/nix"
  elif [ -f /etc/profile.d/nix.sh ]; then
    # shellcheck disable=SC1091
    . /etc/profile.d/nix.sh
    command -v nix >/dev/null 2>&1 && NIX_BIN="$(command -v nix)"
  fi
  if [ -z "$NIX_BIN" ] && [ "${NIX_AUTO_INSTALL_NIX:-1}" -eq 1 ]; then
    if install_nix; then
      command -v nix >/dev/null 2>&1 && NIX_BIN="$(command -v nix)"
    fi
  fi

  if [ -n "$NIX_BIN" ]; then
    if [ "${NIX_AUTO_INSTALL_NIL:-1}" -eq 1 ]; then
      "$NIX_BIN" --extra-experimental-features "nix-command flakes" profile add nixpkgs#nil && NIL_INSTALLED=1 || true
    else
      read -p "Install nil via nix profile (recommended)? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$NIX_BIN" --extra-experimental-features "nix-command flakes" profile add nixpkgs#nil && NIL_INSTALLED=1 || true
      fi
    fi
  fi

  if [ "$NIL_INSTALLED" -ne 1 ] && ! command -v nil >/dev/null 2>&1 && [ "${NIL_OVERLAY_FORCE:-0}" -eq 1 ]; then
    # Attempt overlay for nil (configure NIL_OVERLAY to match your system)
    NIL_OVERLAY="${NIL_OVERLAY:-nix-guix}"
    NIL_OVERLAY_URI="${NIL_OVERLAY_URI:-https://github.com/trofi/nix-guix-gentoo.git}"
    if enable_repo "$NIL_OVERLAY" "git" "$NIL_OVERLAY_URI"; then
      if sudo emerge --noreplace dev-lang/nil; then
        echo -e "${GREEN}✓ nil installed (${NIL_OVERLAY})${NC}"
        NIL_INSTALLED=1
      else
        echo -e "${YELLOW}Warning: nil not available in ${NIL_OVERLAY}${NC}"
      fi
    fi
  fi

  if [ "$NIL_INSTALLED" -eq 1 ] || command -v nil >/dev/null 2>&1; then
    echo -e "${GREEN}✓ nil installed${NC}"
  else
    if [ -z "$NIX_BIN" ]; then
      echo -e "${YELLOW}Warning: nix not found; install nix to get nil (nix profile install nixpkgs#nil)${NC}"
      echo -e "${YELLOW}Tip: set NIX_BIN_OVERRIDE to your nix binary path if it's not on PATH${NC}"
      echo -e "${YELLOW}You can force overlay attempt with NIL_OVERLAY_FORCE=1${NC}"
    fi
    echo -e "${YELLOW}Warning: nil not available${NC}"
    FAILED_BUILD+=("nil")
  fi
fi

echo -e "${BLUE}Step 10: Optional - Install hyprls from repo${NC}"
REPLY="n"
if [ "$FORCE_REINSTALL" -ne 1 ] && hyprls_installed; then
  echo -e "${GREEN}✓ hyprls already installed${NC}"
  HYPRLS_VER=$(hyprls_version)
  [ -n "$HYPRLS_VER" ] && echo -e "${GREEN}  Version: ${HYPRLS_VER}${NC}"
elif [ "${HYPRLS_SKIP:-0}" -eq 1 ]; then
  echo -e "${YELLOW}Skipping hyprls install${NC}"
  echo -e "${YELLOW}Note: set HYPRLS_SKIP=1 to disable hyprls step${NC}"
elif [ "${HYPRLS_PROMPT:-0}" -eq 1 ] && [ -t 0 ]; then
  read -p "Install hyprls from repo? (y/n) " -n 1 -r
  echo
else
  echo -e "${YELLOW}Skipping hyprls install${NC}"
  echo -e "${YELLOW}Note: set HYPRLS_PROMPT=1 to enable prompt${NC}"
fi
if [[ $REPLY =~ ^[Yy]$ ]] && { [ "$FORCE_REINSTALL" -eq 1 ] || ! hyprls_installed; }; then
  echo -e "${BLUE}Installing hyprls build dependencies...${NC}"
  check_and_install_packages dev-lang/go || true

  if ! command -v go >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Go not found; cannot install hyprls${NC}"
    FAILED_BUILD+=("hyprls")
  else
    mkdir -p "$HOME/.local/bin"
    echo -e "${BLUE}Installing hyprls via go install...${NC}"
    if GOBIN="$HOME/.local/bin" go install github.com/hyprland-community/hyprls/cmd/hyprls@latest 2>&1 | tee /tmp/hyprls-build.log; then
      echo -e "${GREEN}✓ hyprls installed to $HOME/.local/bin${NC}"
    else
      echo -e "${YELLOW}⚠ hyprls install failed${NC}"
      FAILED_BUILD+=("hyprls")
      echo "  Build log: /tmp/hyprls-build.log"
    fi
    if ! command -v hyprls >/dev/null 2>&1; then
      echo -e "${YELLOW}Note: add ~/.local/bin to PATH to use hyprls${NC}"
    fi
  fi
else
  echo -e "${YELLOW}Skipping hyprls install${NC}"
  echo -e "${YELLOW}Note: hyprls is optional; only needed for Hyprland configs${NC}"
fi

echo ""

echo -e "${BLUE}Step 11: Verifying installation...${NC}"
echo ""

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
echo "Checking formatters:"
for cmd in stylua shfmt clang-format prettier; do
  if command -v "$cmd" &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $cmd"
  else
    echo -e "  ${YELLOW}○${NC} $cmd (not found, but may be optional)"
  fi
done

echo ""
echo "Checking npm packages:"
if command -v npm &>/dev/null; then
  if npm list -g --prefix "$NPM_PREFIX" @fsouza/prettierd &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} @fsouza/prettierd"
  else
    echo -e "  ${RED}✗${NC} @fsouza/prettierd (missing)"
    MISSING=1
  fi

  if npm list -g --prefix "$NPM_PREFIX" vscode-langservers-extracted &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} vscode-langservers-extracted"
  else
    echo -e "  ${RED}✗${NC} vscode-langservers-extracted (missing)"
    MISSING=1
  fi
else
  echo -e "  ${YELLOW}○${NC} npm not available"
fi

echo ""
echo -e "${BLUE}Step 12: Setting up bugsvim configuration...${NC}"

# Copy nvim directory to ~/.config/nvim
echo -e "${BLUE}Copying nvim config to ~/.config/nvim...${NC}"
cp -r "${SCRIPT_DIR}/nvim" "${HOME}/.config/nvim"
echo -e "${GREEN}✓ bugsvim config copied to ~/.config/nvim${NC}"

# Add npm PATH to shell config if not already present
echo -e "${BLUE}Step 13: Configuring shell PATH for npm...${NC}"

# Detect current shell
CURRENT_SHELL=$(basename "$SHELL")
case "$CURRENT_SHELL" in
zsh)
  SHELL_CONFIG="${HOME}/.zshrc"
  NPM_PATH_LINE="export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
  ;;
bash)
  SHELL_CONFIG="${HOME}/.bashrc"
  NPM_PATH_LINE="export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
  ;;
fish)
  SHELL_CONFIG="${HOME}/.config/fish/config.fish"
  NPM_PATH_LINE="set -gx PATH \$HOME/.npm-global/bin \$PATH"
  ;;
*)
  # For other shells, try .${SHELL}rc pattern
  SHELL_CONFIG="${HOME}/.${CURRENT_SHELL}rc"
  NPM_PATH_LINE="export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
  echo -e "${YELLOW}Note: Detected shell '$CURRENT_SHELL' - using $SHELL_CONFIG${NC}"
  ;;
esac

if [ -f "$SHELL_CONFIG" ]; then
  if ! grep -q "npm-global" "$SHELL_CONFIG"; then
    echo "$NPM_PATH_LINE" >>"$SHELL_CONFIG"
    echo -e "${GREEN}✓ Added npm PATH to $SHELL_CONFIG${NC}"
  else
    echo -e "${GREEN}✓ npm PATH already in $SHELL_CONFIG${NC}"
  fi
else
  echo -e "${YELLOW}Note: Shell config file not found at $SHELL_CONFIG${NC}"
  echo -e "${YELLOW}Please add the following line to your shell config manually:${NC}"
  echo "$NPM_PATH_LINE"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Installation Summary${NC}"
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

if [ ${#FAILED_BUILD[@]} -gt 0 ]; then
  echo -e "${RED}Failed to build/install tools:${NC}"
  for pkg in "${FAILED_BUILD[@]}"; do
    echo "  • $pkg"
  done
  echo ""
fi

if [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ] && [ ${#FAILED_BUILD[@]} -eq 0 ]; then
  echo -e "${GREEN}✓ Installation completed successfully!${NC}"
else
  if [ ${#FAILED_BUILD[@]} -gt 0 ] && [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ Installation mostly successful, but some tools require manual setup${NC}"
  else
    echo -e "${YELLOW}⚠ Installation completed with some issues (see above)${NC}"
  fi
  echo -e "${YELLOW}However, bugsvim config has been installed to ~/.config/nvim${NC}"
  echo -e "${YELLOW}You can install missing components manually if needed${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. Reload your shell: source $SHELL_CONFIG"
echo "  2. Launch neovim: nvim"
echo "  3. Plugins will auto-install on first launch"
echo "  4. Treesitter parsers will auto-install (configured in nvim-treesitter)"
echo "  5. Verify installation: :checkhealth"
echo ""
echo "See POST-INSTALL.md for additional setup and troubleshooting."
