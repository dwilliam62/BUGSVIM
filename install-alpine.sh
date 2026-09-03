#!/usr/bin/emv bash
# ================================================================================================
# bugsvim - Installation Script for Alpine Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Alpine Linux
# Uses doas for privilege escalation (falls back to sudo if available)
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

FORCE_REINSTALL=0
UPDATE_ONLY=0

usage() {
  cat <<'EOF'
Usage: install-alpine.sh [options]

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
    if run_as_root apk add --no-interactive tree-sitter-cli 2>/dev/null; then
      echo -e "${GREEN}✓ tree-sitter-cli installed via apk${NC}"
    elif command -v cargo >/dev/null 2>&1; then
      echo -e "${BLUE}Installing tree-sitter-cli via cargo...${NC}"
      cargo install tree-sitter-cli --root "${HOME}/.local" && echo -e "${GREEN}✓ tree-sitter-cli installed via cargo${NC}"
    else
      echo -e "${RED}✗ Unable to install tree-sitter-cli (install apk package or rust/cargo)${NC}"
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
  echo -e "${BLUE}║   bugsvim - Alpine Linux Update Tasks                          ║${NC}"
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
# run_as_root — prefer doas, fall back to sudo, or direct if already root
# ================================================================================================
run_as_root() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo -e "${RED}Error: This script requires root privileges via doas (preferred) or sudo.${NC}"
    exit 1
  fi
}

npm_pkg_installed() {
  command -v npm >/dev/null 2>&1 && npm list -g "$1" >/dev/null 2>&1
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
echo -e "${BLUE}║   bugsvim - Alpine Linux Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on Alpine
if ! grep -qi "alpine" /etc/os-release 2>/dev/null; then
  echo -e "${YELLOW}Warning: This script is optimized for Alpine Linux.${NC}"
  echo -e "${YELLOW}Detected: $(grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2)${NC}"
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Check NeoVim version (if installed)
echo -e "${BLUE}Checking NeoVim version...${NC}"
if command -v nvim >/dev/null 2>&1; then
  # Parse version using sed only (works with BusyBox); example input: "NVIM v0.11.5"
  NVIM_VERSION=$(nvim --version | sed -n '1{s/^NVIM v//;s/ .*//;p}')
  if [ -n "$NVIM_VERSION" ]; then
    echo -e "${GREEN}✓ NeoVim version: $NVIM_VERSION${NC}"
    MAJOR=$(printf '%s' "$NVIM_VERSION" | cut -d. -f1)
    MINOR=$(printf '%s' "$NVIM_VERSION" | cut -d. -f2)
    if [ "$MAJOR" -lt 0 ] || { [ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 10 ]; }; then
      echo -e "${YELLOW}⚠ NeoVim 0.10+ is recommended for this config${NC}"
      echo -e "${YELLOW}You can try newer packages from your Alpine branch (main/community/edge).${NC}"
    fi
  else
    echo -e "${YELLOW}Warning: could not parse NeoVim version; continuing...${NC}"
  fi
else
  echo -e "${YELLOW}NeoVim not found — it will be installed in Step 2.${NC}"
fi

echo ""

# Backup existing config
backup_neovim_config

echo -e "${BLUE}Step 1: Updating package indexes...${NC}"
run_as_root apk update || true

echo -e "${BLUE}Step 2: Installing core dependencies...${NC}"
run_as_root apk add --no-interactive \
  git \
  ripgrep \
  fd \
  curl \
  jq \
  build-base \
  pkgconf \
  tree-sitter-cli || update_treesitter_cli

echo -e "${BLUE}Step 3: Installing language runtimes and tools...${NC}"
run_as_root apk add --no-interactive \
  python3 \
  py3-pip \
  nodejs \
  npm \
  rust \
  clang \
  cmd:clangd \
  cmd:clang-format || FAILED_PACKAGES+=("lang-tools")

echo -e "${BLUE}Step 3b: Installing Lua Language Server (apk community)...${NC}"
if ! run_as_root apk add --no-interactive lua-language-server; then
  echo -e "${YELLOW}Warning: lua-language-server install failed.${NC}"
  echo -e "${YELLOW}Ensure the 'community' repository is enabled for your Alpine branch.${NC}"
  FAILED_PACKAGES+=("lua-language-server")
fi

echo -e "${BLUE}Step 3c: Configuring npm for user installs...${NC}"
if ! command -v npm >/dev/null 2>&1; then
  echo -e "${RED}✗${NC} npm not found - skipping npm configuration"
  FAILED_PACKAGES+=("npm")
else
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global" --location=per-user 2>/dev/null || true
  export PATH="$HOME/.npm-global/bin:$PATH"
fi

echo -e "${BLUE}Step 3d: Installing bash-language-server (npm)...${NC}"
if command -v npm >/dev/null 2>&1; then
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed bash-language-server; then
    npm install -g bash-language-server || FAILED_NPM+=("bash-language-server")
  else
    echo -e "${GREEN}✓ bash-language-server already installed${NC}"
  fi
else
  echo -e "${YELLOW}Skipping bash-language-server (npm not available)${NC}"
  FAILED_NPM+=("bash-language-server")
fi

echo -e "${BLUE}Step 4: Installing formatters...${NC}"
# shfmt and stylua via apk; prettier via npm
run_as_root apk add --no-interactive shfmt stylua || FAILED_PACKAGES+=("shfmt/stylua")
if command -v npm >/dev/null 2>&1; then
  if [ "$FORCE_REINSTALL" -eq 1 ] || ! npm_pkg_installed prettier; then
    npm install -g prettier || FAILED_NPM+=("prettier")
  else
    echo -e "${GREEN}✓ prettier already installed${NC}"
  fi
fi

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
run_as_root apk add --no-interactive lazygit bat wl-clipboard || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
if command -v npm >/dev/null 2>&1; then
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
    echo -e "${YELLOW}Warning: npm package installation failed${NC}"
  fi
else
  echo -e "${RED}✗${NC} npm not available - skipping npm global packages"
  FAILED_NPM+=("@fsouza/prettierd" "vscode-langservers-extracted" "neovim")
fi

echo -e "${BLUE}Step 7: Installing Python packages (ruff, pyright)...${NC}"
# Prefer distro packages when available (avoids build/toolchain issues)
run_as_root apk add --no-interactive py3-ruff py3-pyright || true

# ruff
if [ "$FORCE_REINSTALL" -eq 1 ] || ! command -v ruff >/dev/null 2>&1; then
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user ruff 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m ensurepip --user 2>/dev/null || true
    python3 -m pip install --user ruff 2>/dev/null || true
  fi
fi
if ! command -v ruff >/dev/null 2>&1; then
  FAILED_PYTHON+=("ruff")
fi

# pyright (language server binary is pyright-langserver)
if [ "$FORCE_REINSTALL" -eq 1 ] || ! command -v pyright-langserver >/dev/null 2>&1; then
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user pyright 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m ensurepip --user 2>/dev/null || true
    python3 -m pip install --user pyright 2>/dev/null || true
  fi
fi
if ! command -v pyright-langserver >/dev/null 2>&1; then
  FAILED_PYTHON+=("pyright")
fi

if [ ${#FAILED_PYTHON[@]} -gt 0 ]; then
  echo -e "${YELLOW}Warning: Python package installs incomplete: ${FAILED_PYTHON[*]}${NC}"
fi

# Get the script directory before any cd operations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BLUE}Step 8: Verifying installation...${NC}"
echo ""

MISSING=0

echo "Checking LSP servers:"
for cmd in lua-language-server clangd; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $cmd"
  else
    echo -e "  ${RED}✗${NC} $cmd (missing)"
    MISSING=1
  fi
done

echo ""
echo "Checking formatters:"
for cmd in stylua shfmt clang-format prettier; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $cmd"
  else
    echo -e "  ${RED}✗${NC} $cmd (missing)"
    MISSING=1
  fi
done

echo ""
echo "Checking npm packages:"
if npm list -g @fsouza/prettierd >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} @fsouza/prettierd"
else
  echo -e "  ${RED}✗${NC} @fsouza/prettierd (missing)"
  MISSING=1
fi
if npm list -g vscode-langservers-extracted >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} vscode-langservers-extracted"
else
  echo -e "  ${RED}✗${NC} vscode-langservers-extracted (missing)"
  MISSING=1
fi

echo ""
echo -e "${BLUE}Step 9: Setting up bugsvim configuration...${NC}"
# Copy nvim directory to ~/.config/nvim
echo -e "${BLUE}Copying nvim config to ~/.config/nvim...${NC}"
cp -r "${SCRIPT_DIR}/nvim" "${HOME}/.config/nvim"
echo -e "${GREEN}✓ bugsvim config copied to ~/.config/nvim${NC}"

echo -e "${BLUE}Step 10: Configuring shell PATH for npm...${NC}"
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

if [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ]; then
  echo -e "${GREEN}✓ Installation completed successfully!${NC}"
else
  echo -e "${YELLOW}⚠ Installation completed with some issues (see above)${NC}"
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
