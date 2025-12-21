#!/bin/bash
# ================================================================================================
# bugsvim - Installation Script for Debian/Ubuntu
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Debian/Ubuntu
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
FAILED_HYPRLS=()

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
echo -e "${BLUE}║   bugsvim - Debian/Ubuntu Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check NeoVim version
echo -e "${BLUE}Checking NeoVim version...${NC}"
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}✗ NeoVim is not installed${NC}"
    echo -e "${RED}This configuration requires NeoVim to be installed first${NC}"
    echo -e "${RED}Install NeoVim with: sudo apt-get install neovim${NC}"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -1 | grep -oP 'NVIM v\K[^\s]+')
echo -e "${GREEN}✓ NeoVim version: $NVIM_VERSION${NC}"

# Check if version is 0.10 or higher
MAJOR=$(echo $NVIM_VERSION | cut -d. -f1)
MINOR=$(echo $NVIM_VERSION | cut -d. -f2)

if [ "$MAJOR" -lt 0 ] || ([ "$MAJOR" -eq 0 ] && [ "$MINOR" -lt 10 ]); then
    echo -e "${RED}✗ NeoVim version 0.10 or higher is required${NC}"
    echo -e "${RED}Current version: $NVIM_VERSION${NC}"
    echo ""
    echo -e "${YELLOW}Debian/Ubuntu usually packages older versions of NeoVim${NC}"
    echo -e "${YELLOW}A pre-built package with NeoVim 0.11+ is available at:${NC}"
    echo -e "${YELLOW}https://codeberg.org/justaguylinux/nvim${NC}"
    echo ""
    echo -e "${YELLOW}This includes an install script for easy setup.${NC}"
    exit 1
fi

echo ""

# Backup existing config
backup_neovim_config
echo ""

# Check if running on Debian/Ubuntu
if ! grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}Warning: This script is optimized for Debian/Ubuntu.${NC}"
    echo -e "${YELLOW}Detected: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Get the script directory before any cd operations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Step 1: Updating package manager...${NC}"
sudo apt-get update

echo -e "${BLUE}Step 2: Installing core dependencies...${NC}"
sudo apt-get install -y \
    neovim \
    git \
    ripgrep \
    fd-find \
    curl \
    build-essential \
    pkg-config

echo -e "${BLUE}Step 3: Installing language servers from apt...${NC}"
sudo apt-get install -y \
    lua5.1 \
    python3-venv \
    python3-pip \
    nodejs \
    npm \
    clang \
    clangd \
    clang-tools \
    rustup || true

echo -e "${BLUE}Step 3b: Setting up npm for global installs...${NC}"
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗${NC} npm not found - skipping npm configuration"
    FAILED_PACKAGES+=("npm")
else
    # Configure npm to use user directory instead of global (avoids permission issues)
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global' --location=per-user 2>/dev/null || true
    export PATH=~/.npm-global/bin:$PATH
fi

echo -e "${BLUE}Step 3c: Installing language servers from npm...${NC}"
echo -e "${YELLOW}Note: lua-language-server must be installed separately${NC}"
echo -e "${YELLOW}Install from: https://github.com/LuaLS/lua-language-server/releases${NC}"

echo -e "${BLUE}  Installing bash-language-server...${NC}"
npm install -g bash-language-server || echo -e "${YELLOW}Warning: bash-language-server install failed${NC}"


echo -e "${BLUE}Step 4: Installing formatters...${NC}"
# Install formatters that are available
echo -e "${BLUE}  Installing shfmt...${NC}"
sudo apt-get install -y shfmt || echo -e "${YELLOW}Warning: shfmt not available${NC}"

echo -e "${BLUE}  Installing clang-format...${NC}"
sudo apt-get install -y clang-format || echo -e "${YELLOW}Warning: clang-format not available${NC}"

# stylua and prettier install via npm
echo -e "${BLUE}  Installing stylua (Lua formatter)...${NC}"
npm install -g @johnnymorganz/stylua-bin || echo -e "${YELLOW}Warning: stylua install failed${NC}"

echo -e "${BLUE}  Installing prettier (Web formatter)...${NC}"
npm install -g prettier || echo -e "${YELLOW}Warning: prettier install failed${NC}"

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
sudo apt-get install -y \
    lazygit \
    bat \
    wl-clipboard || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
if command -v npm &> /dev/null; then
    echo -e "${BLUE}  Installing prettierd...${NC}"
    npm install -g @fsouza/prettierd || FAILED_NPM+=("@fsouza/prettierd")
    
    echo -e "${BLUE}  Installing vscode-langservers...${NC}"
    npm install -g vscode-langservers-extracted || FAILED_NPM+=("vscode-langservers-extracted")
else
    echo -e "${RED}✗${NC} npm not available - skipping npm global packages"
    FAILED_NPM+=("@fsouza/prettierd" "vscode-langservers-extracted")
fi

echo -e "${BLUE}Step 7: Installing Python packages...${NC}"
# Ubuntu/Debian enforces PEP 668, use --break-system-packages for user installs
PYTHON_INSTALLED=0

if command -v pip3 &> /dev/null; then
    pip3 install --user --break-system-packages ruff pyright 2>/dev/null && PYTHON_INSTALLED=1
fi

if [ $PYTHON_INSTALLED -eq 0 ] && command -v python3 &> /dev/null; then
    python3 -m ensurepip --user 2>/dev/null || true
    python3 -m pip install --user --break-system-packages ruff pyright 2>/dev/null && PYTHON_INSTALLED=1
fi

if [ $PYTHON_INSTALLED -eq 0 ]; then
    FAILED_PYTHON+=("ruff" "pyright")
    echo -e "${YELLOW}Warning: Python packages install failed${NC}"
fi

echo -e "${BLUE}Step 8: Optional - Build hyprls from source${NC}"
read -p "Build hyprls from source? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Installing hyprls build dependencies...${NC}"
    sudo apt-get install -y cmake meson wayland-protocols libwayland-dev libxcb-render0-dev libxcb-shape0-dev || true
    
    if [ -d /tmp/hyprland ]; then
        rm -rf /tmp/hyprland
    fi
    echo -e "${BLUE}Cloning hyprland repository...${NC}"
    (cd /tmp && git clone --depth 1 https://github.com/hyprwm/hyprland.git)
    echo -e "${BLUE}Building hyprls...${NC}"
    if (cd /tmp/hyprland && cmake -B build && cmake --build build --target hyprls 2>/dev/null); then
        echo -e "${BLUE}Installing hyprls...${NC}"
        sudo cp /tmp/hyprland/build/hyprls /usr/local/bin/ 2>/dev/null || sudo install -m 755 /tmp/hyprland/build/hyprls /usr/local/bin/
        echo -e "${GREEN}✓ hyprls installed${NC}"
    else
        echo -e "${YELLOW}⚠ hyprls build failed (check dependencies)${NC}"
        FAILED_HYPRLS+=("hyprls")
        echo "  Install build dependencies: cmake, meson, wayland-protocols, libwayland-dev"
    fi
else
    echo -e "${YELLOW}Skipping hyprls build${NC}"
    echo -e "${YELLOW}Note: hyprls is optional; only needed for Hyprland configs${NC}"
fi

echo ""

echo -e "${BLUE}Step 9: Verifying installation...${NC}"
echo ""

MISSING=0

echo "Checking LSP servers:"
for cmd in clangd; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd"
    else
        echo -e "  ${RED}✗${NC} $cmd (missing)"
        MISSING=1
    fi
done

echo ""
echo "Checking formatters:"
for cmd in stylua shfmt clang-format; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd"
    else
        echo -e "  ${RED}✗${NC} $cmd (missing)"
        MISSING=1
    fi
done

echo ""
echo "Checking npm packages:"
if npm list -g @fsouza/prettierd &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} @fsouza/prettierd"
else
    echo -e "  ${RED}✗${NC} @fsouza/prettierd (missing)"
    MISSING=1
fi

if npm list -g vscode-langservers-extracted &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} vscode-langservers-extracted"
else
    echo -e "  ${RED}✗${NC} vscode-langservers-extracted (missing)"
    MISSING=1
fi

echo ""
echo "Checking Python packages:"
if python3 -c "import pyright" 2>/dev/null || python3 -m pip show pyright &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} pyright"
else
    echo -e "  ${RED}✗${NC} pyright (missing)"
    MISSING=1
fi

echo ""
echo -e "${BLUE}Step 10: Setting up bugsvim configuration...${NC}"

# Copy nvim directory to ~/.config/nvim
echo -e "${BLUE}Copying nvim config to ~/.config/nvim...${NC}"
cp -r "${SCRIPT_DIR}/nvim" "${HOME}/.config/nvim"
echo -e "${GREEN}✓ bugsvim config copied to ~/.config/nvim${NC}"

# Add npm PATH to shell config if not already present
echo -e "${BLUE}Step 11: Configuring shell PATH for npm...${NC}"

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
        echo "$NPM_PATH_LINE" >> "$SHELL_CONFIG"
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

if [ ${#FAILED_HYPRLS[@]} -gt 0 ]; then
    echo -e "${RED}Failed to build optional tools:${NC}"
    for pkg in "${FAILED_HYPRLS[@]}"; do
        echo "  • $pkg (optional)"
    done
    echo ""
fi

if [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ] && [ ${#FAILED_HYPRLS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Installation completed successfully!${NC}"
else
    if [ ${#FAILED_HYPRLS[@]} -gt 0 ] && [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ Installation mostly successful, but optional tools failed${NC}"
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
