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

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   bugsvim - Debian/Ubuntu Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on Debian/Ubuntu
if ! grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}Warning: This script is optimized for Debian/Ubuntu.${NC}"
    echo -e "${YELLOW}Detected: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

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

echo -e "${BLUE}Step 3: Installing language servers...${NC}"
sudo apt-get install -y \
    lua5.1 \
    lua-language-server \
    python3-venv \
    python3-pip \
    nodejs \
    npm \
    clang \
    clang-tools \
    bash-language-server \
    rustup \
    nil

echo -e "${BLUE}Step 4: Installing formatters...${NC}"
sudo apt-get install -y \
    stylua \
    shfmt \
    clang-format \
    prettier

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
sudo apt-get install -y \
    lazygit \
    bat \
    wl-clipboard || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
npm install -g @fsouza/prettierd vscode-langservers-extracted

echo -e "${BLUE}Step 7: Installing Python packages...${NC}"
pip3 install --user ruff pyright

echo -e "${BLUE}Step 8: Optional - Build hyprls from source${NC}"
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
echo -e "${BLUE}Step 9: Verifying installation...${NC}"
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
if [ $MISSING -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Installation completed successfully! ✓${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Clone bugsvim: git clone https://github.com/ddubs/bugsvim ~/.config/nvim"
    echo "  2. Launch neovim: nvim"
    echo "  3. Verify LSP: :LspInfo"
else
    echo -e "${YELLOW}Some components are missing. Check output above.${NC}"
    exit 1
fi
