#!/bin/bash
# ================================================================================================
# bugsvim - Installation Script for Fedora
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Fedora
# ================================================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ================================================================================================
# Backup existing NeoVim configuration
# ================================================================================================
backup_neovim_config() {
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_dir="${HOME}/neovim-backup-${timestamp}"
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
    else
        echo -e "${GREEN}✓ No existing NeoVim configuration found${NC}"
    fi
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   bugsvim - Fedora Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Backup existing config
backup_neovim_config
echo ""

# Check if running on Fedora
if ! grep -qi "fedora" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}Warning: This script is optimized for Fedora.${NC}"
    echo -e "${YELLOW}Detected: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

echo -e "${BLUE}Step 1: Updating package manager...${NC}"
sudo dnf update -y

echo -e "${BLUE}Step 2: Installing core dependencies...${NC}"
sudo dnf install -y \
    neovim \
    git \
    ripgrep \
    fd \
    curl \
    @development-tools \
    pkg-config

echo -e "${BLUE}Step 3: Installing language servers...${NC}"
sudo dnf install -y \
    lua \
    python3-devel \
    python3-pip \
    nodejs \
    npm \
    clang \
    clang-tools-extra \
    rust

echo -e "${BLUE}Step 3b: Configuring npm for user installs...${NC}"
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global' --location=per-user 2>/dev/null || true
export PATH=~/.npm-global/bin:$PATH

echo -e "${BLUE}Step 3c: Checking for language servers...${NC}"

echo -e "${BLUE}  Checking lua-language-server...${NC}"
if dnf list lua-language-server &>/dev/null 2>&1; then
    sudo dnf install -y lua-language-server
else
    echo -e "${YELLOW}lua-language-server not available in Fedora repos${NC}"
    echo -e "${YELLOW}Installing lua-language-server via npm...${NC}"
    npm install -g lua-language-server || echo -e "${YELLOW}Warning: lua-language-server install failed${NC}"
fi

echo -e "${BLUE}  Checking bash-language-server...${NC}"
if dnf list bash-language-server &>/dev/null 2>&1; then
    sudo dnf install -y bash-language-server
else
    echo -e "${YELLOW}bash-language-server not available - will install via npm${NC}"
    npm install -g bash-language-server || echo -e "${YELLOW}Warning: bash-language-server install failed${NC}"
fi

echo -e "${BLUE}Step 3d: Checking for nil (Nix LSP)...${NC}"
if command -v nil &>/dev/null; then
    echo -e "${GREEN}✓ nil already installed${NC}"
else
    echo -e "${YELLOW}nil not available in Fedora repos${NC}"
    echo -e "${YELLOW}To install nil, visit: https://github.com/oxalica/nil${NC}"
fi

echo -e "${BLUE}Step 4: Installing formatters...${NC}"

echo -e "${BLUE}  Installing shfmt...${NC}"
sudo dnf install -y shfmt || echo -e "${YELLOW}Warning: shfmt not available${NC}"

echo -e "${BLUE}  Installing clang-format (via clang-tools-extra)...${NC}"
sudo dnf install -y clang-tools-extra || echo -e "${YELLOW}Warning: clang-tools-extra not available${NC}"

echo -e "${BLUE}  Installing stylua and prettier via npm...${NC}"
npm install -g @johnnymorganz/stylua-bin || echo -e "${YELLOW}Warning: stylua install failed${NC}"
npm install -g prettier || echo -e "${YELLOW}Warning: prettier install failed${NC}"

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
sudo dnf install -y \
    lazygit \
    bat \
    wl-clipboard || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
npm install -g @fsouza/prettierd vscode-langservers-extracted

echo -e "${BLUE}Step 7: Installing Python packages...${NC}"
pip3 install --user ruff pyright

echo -e "${BLUE}Step 8: Verifying Rust installation...${NC}"
if command -v rustc &> /dev/null; then
    echo -e "${GREEN}✓ Rust already available${NC}"
else
    echo -e "${YELLOW}Rust not found - it may need to be installed separately${NC}"
fi

echo -e "${BLUE}Step 9: Optional - Build hyprls from source${NC}"
if [ -d /tmp/hyprland ]; then
    rm -rf /tmp/hyprland
fi
read -p "Build hyprls from source? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Cloning hyprland repository...${NC}"
    cd /tmp
    git clone --depth 1 https://github.com/hyprwm/hyprland.git
    cd hyprland
    echo -e "${BLUE}Building hyprls...${NC}"
    if make hyprls 2>/dev/null; then
        echo -e "${BLUE}Installing hyprls...${NC}"
        sudo cp /tmp/hyprland/hyprls /usr/local/bin/
        echo -e "${GREEN}✓ hyprls installed${NC}"
    else
        echo -e "${YELLOW}⚠ hyprls build skipped (requires additional dependencies)${NC}"
        echo "  You can manually build later: cd /tmp/hyprland && make hyprls"
    fi
else
    echo -e "${YELLOW}Skipping hyprls build${NC}"
    echo -e "${YELLOW}Note: hyprls is optional; only needed for Hyprland configs${NC}"
fi

echo ""
echo -e "${BLUE}Step 10: Verifying installation...${NC}"
echo ""

MISSING=0

echo "Checking LSP servers:"
for cmd in lua-language-server clangd nil; do
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
if python3 -c "import pyright" 2>/dev/null || pip3 show pyright &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} pyright"
else
    echo -e "  ${RED}✗${NC} pyright (missing)"
    MISSING=1
fi

echo ""
echo "Checking Rust toolchain:"
if command -v rustc &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} rustc"
else
    echo -e "  ${RED}✗${NC} rustc (missing)"
    MISSING=1
fi

echo ""
if [ $MISSING -eq 0 ]; then
    echo -e "${BLUE}Step 11: Setting up bugsvim configuration...${NC}"
    
    # Copy nvim directory to ~/.config/nvim
    echo -e "${BLUE}Copying nvim config to ~/.config/nvim...${NC}"
    cp -r "$(pwd)/nvim" "${HOME}/.config/nvim"
    echo -e "${GREEN}✓ bugsvim config copied to ~/.config/nvim${NC}"
    
    # Add npm PATH to shell config if not already present
    echo -e "${BLUE}Step 12: Configuring shell PATH for npm...${NC}"
    SHELL_CONFIG="${HOME}/.$(basename $SHELL)rc"
    NPM_PATH_LINE="export PATH=\"$HOME/.npm-global/bin:\$PATH\""
    
    if [ -f "$SHELL_CONFIG" ]; then
        if ! grep -q "npm-global" "$SHELL_CONFIG"; then
            echo "$NPM_PATH_LINE" >> "$SHELL_CONFIG"
            echo -e "${GREEN}✓ Added npm PATH to $SHELL_CONFIG${NC}"
        else
            echo -e "${GREEN}✓ npm PATH already in $SHELL_CONFIG${NC}"
        fi
    else
        echo -e "${YELLOW}Creating $SHELL_CONFIG...${NC}"
        echo "$NPM_PATH_LINE" > "$SHELL_CONFIG"
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Installation completed successfully! ✓${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Reload your shell: source $SHELL_CONFIG"
    echo "  2. Launch neovim: nvim"
    echo "  3. Plugins will auto-install on first launch"
    echo "  4. Verify LSP: :LspInfo"
    echo ""
    echo "See POST-INSTALL.md for additional setup and troubleshooting."
else
    echo -e "${YELLOW}Some components are missing. Check output above.${NC}"
    exit 1
fi
