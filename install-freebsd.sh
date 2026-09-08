#!/usr/bin/env bash
# ================================================================================================
# bugsvim - Installation Script for FreeBSD
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on FreeBSD
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
FAILED_LUALS=()

FORCE_REINSTALL=0
UPDATE_ONLY=0
DEPS_ONLY=0

usage() {
  cat <<'EOF'
Usage: install-freebsd.sh [options]

Options:
  -f, --force    Force rebuild/reinstall of optional packages
  -u, --update   Run update tasks (check/install tree-sitter-cli, clean legacy caches, sync config)
  -d, --deps     Check for all dependencies and install missing ones
  -h, --help     Show this help message
EOF
}

for arg in "$@"; do
  case "$arg" in
  -f | --force) FORCE_REINSTALL=1 ;;
  -u | --update) UPDATE_ONLY=1 ;;
  -d | --deps) DEPS_ONLY=1 ;;
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
    if run_as_root pkg install -y tree-sitter-cli 2>/dev/null; then
      echo -e "${GREEN}✓ tree-sitter-cli installed via pkg${NC}"
    elif command -v cargo >/dev/null 2>&1; then
      echo -e "${BLUE}Installing tree-sitter-cli via cargo...${NC}"
      cargo install tree-sitter-cli --root "${HOME}/.local" && echo -e "${GREEN}✓ tree-sitter-cli installed via cargo${NC}"
    else
      echo -e "${RED}✗ Unable to install tree-sitter-cli (install pkg package or rust/cargo)${NC}"
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
  echo -e "${BLUE}║   bugsvim - FreeBSD Update Tasks                               ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  for task in "${UPDATE_TASKS[@]}"; do
    "$task"
    echo ""
  done
  echo -e "${GREEN}✓ All update tasks completed successfully!${NC}"
  echo "Next steps: Launch 'nvim' and run ':Lazy sync' or ':TSUpdate' if needed."
}

verify_installation() {
  MISSING=0

  echo "Checking LSP servers:"
  for cmd in clangd; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${RED}✗${NC} $cmd (missing)"
      MISSING=1
    fi
  done

  echo ""
  echo "Checking formatters and linters:"
  for cmd in stylua luacheck shfmt clang-format; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $cmd"
    else
      echo -e "  ${RED}✗${NC} $cmd (missing)"
      MISSING=1
    fi
  done

  echo ""
  echo "Checking npm packages:"
  if npm list -g @fsouza/prettierd &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} @fsouza/prettierd"
  else
    echo -e "  ${RED}✗${NC} @fsouza/prettierd (missing)"
    MISSING=1
  fi

  if npm list -g vscode-langservers-extracted &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} vscode-langservers-extracted"
  else
    echo -e "  ${RED}✗${NC} vscode-langservers-extracted (missing)"
    MISSING=1
  fi

  echo ""
  echo "Checking Rust toolchain:"
  if command -v rustc &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} rustc"
  else
    echo -e "  ${RED}✗${NC} rustc (missing - can be installed via rustup)"
    MISSING=1
  fi
}

check_and_install_deps() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   bugsvim - Checking and Installing Dependencies               ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  echo -e "${BLUE}Updating package manager...${NC}"
  run_as_root pkg update

  echo -e "${BLUE}Installing missing pkg packages...${NC}"
  run_as_root pkg install -y \
    git \
    ripgrep \
    fd-find \
    curl \
    jq \
    base64 \
    gmake \
    pkgconf \
    tree-sitter-cli \
    lua \
    lua-luarocks \
    lua-luacheck \
    lua51-luacheck \
    python3 \
    py3-pip \
    node \
    npm \
    llvm \
    bash \
    shfmt \
    stylua \
    lazygit \
    bat \
    xclip || true

  # luacheck
  if ! command -v luacheck &>/dev/null && command -v luarocks &>/dev/null; then
    echo -e "${BLUE}Installing luacheck via luarocks...${NC}"
    run_as_root luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi

  # npm config & packages
  if command -v npm &>/dev/null; then
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global' --location=per-user 2>/dev/null || true
    export PATH=~/.npm-global/bin:$PATH

    local npm_pkgs=(bash-language-server prettier @fsouza/prettierd vscode-langservers-extracted neovim)
    for pkg in "${npm_pkgs[@]}"; do
      if ! npm_pkg_installed "$pkg"; then
        echo -e "${BLUE}Installing missing npm package: $pkg...${NC}"
        npm install -g "$pkg" || FAILED_NPM+=("$pkg")
      else
        echo -e "${GREEN}✓ npm package $pkg already installed${NC}"
      fi
    done
  fi

  # Rust
  if ! command -v rustc &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || true
  fi

  update_treesitter_cli

  echo ""
  echo -e "${BLUE}Verifying dependencies...${NC}"
  echo ""
  verify_installation
  echo ""
  if [ $MISSING -eq 0 ]; then
    echo -e "${GREEN}✓ All dependencies are satisfied!${NC}"
  else
    echo -e "${YELLOW}⚠ Some dependencies are missing (see above)${NC}"
  fi
}

if [ "$UPDATE_ONLY" -eq 1 ]; then
  run_update_tasks
  exit 0
fi

if [ "$DEPS_ONLY" -eq 1 ]; then
  check_and_install_deps
  exit 0
fi

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
echo -e "${BLUE}║   bugsvim - FreeBSD Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check NeoVim version
echo -e "${BLUE}Checking NeoVim version...${NC}"
if ! command -v nvim &>/dev/null; then
  echo -e "${RED}✗ NeoVim is not installed${NC}"
  echo -e "${RED}This configuration requires NeoVim to be installed first${NC}"
  echo -e "${RED}Install NeoVim with: sudo pkg install neovim${NC}"
  exit 1
fi

NVIM_VERSION=$(nvim --version | head -1 | sed -E 's/^NVIM v([^[:space:]]+).*/\1/')
echo -e "${GREEN}✓ NeoVim version: $NVIM_VERSION${NC}"

# Check if version is 0.10 or higher
MAJOR=$(echo $NVIM_VERSION | cut -d. -f1)
MINOR=$(echo $NVIM_VERSION | cut -d. -f2)

if [ "$MAJOR" -lt 0 ] || ([ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 10 ]); then
  echo -e "${RED}✗ NeoVim version 0.10 or higher is required${NC}"
  echo -e "${RED}Current version: $NVIM_VERSION${NC}"
  echo -e "${YELLOW}Please upgrade NeoVim: sudo pkg upgrade neovim${NC}"
  exit 1
fi

echo ""

# Backup existing config
backup_neovim_config
echo ""

# Check if running on FreeBSD
if ! uname -s | grep -q "FreeBSD" 2>/dev/null; then
  echo -e "${YELLOW}Warning: This script is optimized for FreeBSD.${NC}"
  echo -e "${YELLOW}Detected: $(uname -s)${NC}"
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Check if running as root or can use sudo
if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
  echo -e "${RED}Error: This script requires root privileges or sudo access${NC}"
  exit 1
fi

# Function to run commands with sudo if needed
run_as_root() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

npm_pkg_installed() {
  command -v npm >/dev/null 2>&1 && npm list -g "$1" >/dev/null 2>&1
}

echo -e "${BLUE}Step 1: Updating package manager...${NC}"
run_as_root pkg update

echo -e "${BLUE}Step 2: Installing core dependencies...${NC}"
run_as_root pkg install -y \
  git \
  ripgrep \
  fd-find \
  curl \
  jq \
  base64 \
  gmake \
  pkgconf \
  tree-sitter-cli || true
update_treesitter_cli

echo -e "${BLUE}Step 3: Installing language servers...${NC}"
run_as_root pkg install -y \
  lua \
  lua-luarocks \
  python3 \
  py3-pip \
  node \
  npm \
  llvm \
  bash || true

echo -e "${BLUE}Step 3b: Configuring npm for user installs...${NC}"
if ! command -v npm &>/dev/null; then
  echo -e "${RED}✗${NC} npm not found - skipping npm configuration"
  FAILED_PACKAGES+=("npm")
else
  mkdir -p ~/.npm-global
  npm config set prefix '~/.npm-global' --location=per-user 2>/dev/null || true
  export PATH=~/.npm-global/bin:$PATH
fi

echo -e "${BLUE}Step 3c: Installing bash-language-server...${NC}"
if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed bash-language-server; then
  npm install -g bash-language-server || echo -e "${YELLOW}Warning: bash-language-server install failed${NC}"
else
  echo -e "${GREEN}✓ bash-language-server already installed${NC}"
fi

echo -e "${BLUE}Step 4: Installing formatters...${NC}"

echo -e "${BLUE}  Installing shfmt...${NC}"
run_as_root pkg install -y shfmt || echo -e "${YELLOW}Warning: shfmt not available${NC}"

echo -e "${BLUE}  Installing clang-format (via llvm)...${NC}"
run_as_root pkg install -y llvm || echo -e "${YELLOW}Warning: llvm not available${NC}"

echo -e "${BLUE}  Installing stylua (via pkg) and prettier (via npm)...${NC}"
run_as_root pkg install -y stylua || echo -e "${YELLOW}Warning: stylua not available${NC}"
if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed prettier; then
  npm install -g prettier || echo -e "${YELLOW}Warning: prettier install failed${NC}"
else
  echo -e "${GREEN}✓ prettier already installed${NC}"
fi

echo -e "${BLUE}  Installing luacheck (Lua linter)...${NC}"
run_as_root pkg install -y lua51-luacheck lua-luacheck luacheck 2>/dev/null || true
if ! command -v luacheck &>/dev/null; then
  if command -v luarocks &>/dev/null; then
    echo -e "${BLUE}  Installing luacheck via luarocks...${NC}"
    run_as_root luarocks install luacheck 2>/dev/null || luarocks install --local luacheck 2>/dev/null || true
  fi
fi
if command -v luacheck &>/dev/null; then
  echo -e "${GREEN}✓ luacheck installed${NC}"
else
  echo -e "${YELLOW}Warning: luacheck not available${NC}"
fi

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
run_as_root pkg install -y \
  lazygit \
  bat \
  xclip || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
if command -v npm &>/dev/null; then
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed @fsouza/prettierd; then
    npm install -g @fsouza/prettierd || FAILED_NPM+=("@fsouza/prettierd")
  else
    echo -e "${GREEN}✓ @fsouza/prettierd already installed${NC}"
  fi
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed vscode-langservers-extracted; then
    npm install -g vscode-langservers-extracted || FAILED_NPM+=("vscode-langservers-extracted")
  else
    echo -e "${GREEN}✓ vscode-langservers-extracted already installed${NC}"
  fi
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed neovim; then
    npm install -g neovim || FAILED_NPM+=("neovim")
  else
    echo -e "${GREEN}✓ neovim (npm) already installed${NC}"
  fi
  if [ ${#FAILED_NPM[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warning: npm packages install failed${NC}"
  fi
else
  echo -e "${RED}✗${NC} npm not available - skipping npm global packages"
  FAILED_NPM+=("@fsouza/prettierd" "vscode-langservers-extracted" "neovim")
fi

echo -e "${BLUE}Step 7: Skipping Python packages (ruff/pyright removed)...${NC}"

echo -e "${YELLOW}Note: lua-language-server must be installed separately${NC}"
echo -e "${YELLOW}Install from: https://github.com/LuaLS/lua-language-server/releases${NC}"
echo -e "${YELLOW}Or build from ports: cd /usr/ports/devel/lua-language-server && make install clean${NC}"

echo -e "${BLUE}Step 8: Checking for Rust...${NC}"
if command -v rustc &>/dev/null; then
  echo -e "${GREEN}✓ Rust already available${NC}"
else
  echo -e "${YELLOW}Rust not found - installing via rustup${NC}"
  # Install rustup for Rust installation
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y ||
    echo -e "${YELLOW}Warning: Rust installation failed${NC}"
fi

echo ""

# Get the script directory before any cd operations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Step 9: Optional - Install lua-language-server from ports${NC}"
read -p "Install lua-language-server from ports? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if pkg info -e lua-language-server >/dev/null 2>&1; then
    echo -e "${GREEN}✓ lua-language-server already installed${NC}"
  elif [ -d /usr/ports/devel/lua-language-server ]; then
    echo -e "${BLUE}Building lua-language-server from ports...${NC}"
    if (cd /usr/ports/devel/lua-language-server && run_as_root make install clean); then
      echo -e "${GREEN}✓ lua-language-server installed${NC}"
    else
      echo -e "${YELLOW}Warning: lua-language-server build failed${NC}"
      FAILED_LUALS+=("lua-language-server")
    fi
  else
    echo -e "${YELLOW}lua-language-server not found in ports${NC}"
    FAILED_LUALS+=("lua-language-server")
    echo -e "${YELLOW}Try updating ports first: portsnap fetch update${NC}"
  fi
else
  echo -e "${YELLOW}Skipping lua-language-server from ports${NC}"
fi

echo ""
echo -e "${BLUE}Step 10: Verifying installation...${NC}"
echo ""

verify_installation
echo ""
echo -e "${BLUE}Step 11: Setting up bugsvim configuration...${NC}"

# Copy nvim directory to ~/.config/nvim
echo -e "${BLUE}Copying nvim config to ~/.config/nvim...${NC}"
cp -r "${SCRIPT_DIR}/nvim" "${HOME}/.config/nvim"
echo -e "${GREEN}✓ bugsvim config copied to ~/.config/nvim${NC}"

# Add npm PATH to shell config if not already present
echo -e "${BLUE}Step 12: Configuring shell PATH for npm...${NC}"

# Detect current shell
CURRENT_SHELL=$(basename "$SHELL")
case "$CURRENT_SHELL" in
zsh)
  SHELL_CONFIG="${HOME}/.zshrc"
  NPM_PATH_LINE="export PATH=\"$HOME/.npm-global/bin:\$PATH\""
  ;;
bash)
  SHELL_CONFIG="${HOME}/.bashrc"
  NPM_PATH_LINE="export PATH=\"$HOME/.npm-global/bin:\$PATH\""
  ;;
fish)
  SHELL_CONFIG="${HOME}/.config/fish/config.fish"
  NPM_PATH_LINE="set -gx PATH \$HOME/.npm-global/bin \$PATH"
  ;;
*)
  # For other shells, try .${SHELL}rc pattern
  SHELL_CONFIG="${HOME}/.${CURRENT_SHELL}rc"
  NPM_PATH_LINE="export PATH=\"$HOME/.npm-global/bin:\$PATH\""
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

if [ ${#FAILED_LUALS[@]} -gt 0 ]; then
  echo -e "${RED}Failed to build optional tools:${NC}"
  for pkg in "${FAILED_LUALS[@]}"; do
    echo "  • $pkg (optional)"
  done
  echo ""
fi

if [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ] && [ ${#FAILED_LUALS[@]} -eq 0 ]; then
  echo -e "${GREEN}✓ Installation completed successfully!${NC}"
else
  if [ ${#FAILED_LUALS[@]} -gt 0 ] && [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ Installation mostly successful, but optional tools failed${NC}"
  else
    echo -e "${YELLOW}⚠ Installation completed with some issues (see above)${NC}"
  fi
  echo -e "${YELLOW}However, bugsvim config has been installed to ~/.config/nvim${NC}"
fi

echo ""
echo "Next steps:"
if [ -f "$SHELL_CONFIG" ]; then
  echo "  1. Reload your shell: source $SHELL_CONFIG"
else
  echo "  1. Add npm PATH to your shell config (see note above), then reload"
fi
echo "  2. Launch neovim: nvim"
echo "  3. Plugins will auto-install on first launch"
echo "  4. Treesitter parsers will auto-install (configured in nvim-treesitter)"
echo "  5. Verify installation: :checkhealth"
echo ""
echo "See POST-INSTALL.md for additional setup and troubleshooting."
