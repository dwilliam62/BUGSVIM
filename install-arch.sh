#!/bin/bash
# ================================================================================================
# bugsvim - Installation Script for Arch Linux
# ================================================================================================
# This script installs all dependencies and language servers for bugsvim on Arch Linux
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
echo -e "${BLUE}║   bugsvim - Arch Linux Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Backup existing config
backup_neovim_config
echo ""

# Check if running on Arch
if ! grep -q "Arch" /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}Warning: This script is optimized for Arch Linux.${NC}"
    echo -e "${YELLOW}Detected: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

echo -e "${BLUE}Step 1: Updating package manager...${NC}"
sudo pacman -Sy --noconfirm

echo -e "${BLUE}Step 2: Installing core dependencies...${NC}"
sudo pacman -S --needed --noconfirm \
    neovim \
    git \
    ripgrep \
    fd \
    curl \
    base-devel \
    pkg-config

echo -e "${BLUE}Step 3: Installing language servers...${NC}"
sudo pacman -S --needed --noconfirm \
    lua-language-server \
    python \
    nodejs \
    npm \
    clang \
    bash-language-server

echo -e "${BLUE}Step 3b: Installing Rust (checking for conflicts)...${NC}"
if pacman -Q rustup &>/dev/null; then
    echo -e "${GREEN}✓ rustup already installed${NC}"
elif pacman -Q rust &>/dev/null; then
    echo -e "${YELLOW}rust package found (from official repos)${NC}"
    echo -e "${YELLOW}Not installing rustup to avoid conflicts${NC}"
else
    sudo pacman -S --needed --noconfirm rustup
fi

echo -e "${BLUE}Step 3c: Checking for nil (Nix LSP)...${NC}"
if command -v nil &>/dev/null; then
    echo -e "${GREEN}✓ nil already installed${NC}"
else
    echo -e "${YELLOW}nil not in official Arch repos${NC}"
    echo -e "${YELLOW}Available via AUR: yay -S nil${NC}"
fi

echo -e "${BLUE}Step 4: Installing formatters...${NC}"
sudo pacman -S --needed --noconfirm \
    stylua \
    shfmt \
    clang \
    prettier

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
sudo pacman -S --noconfirm \
    lazygit \
    bat \
    wl-clipboard || true

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
npm install -g @fsouza/prettierd vscode-langservers-extracted

echo -e "${BLUE}Step 7: Checking for AUR helper...${NC}"
if command -v yay &> /dev/null; then
    echo -e "${GREEN}✓ yay found${NC}"
    echo -e "${BLUE}Step 8: Installing AUR packages (recommended)...${NC}"
    yay -S --noconfirm \
        hyprls \
        pyright \
        alejandra-bin \
        prettierd || true
elif command -v paru &> /dev/null; then
    echo -e "${GREEN}✓ paru found${NC}"
    echo -e "${BLUE}Step 8: Installing AUR packages (recommended)...${NC}"
    paru -S --noconfirm \
        hyprls \
        pyright \
        alejandra-bin \
        prettierd || true
else
    echo -e "${YELLOW}⚠ No AUR helper found (yay/paru)${NC}"
    echo -e "${YELLOW}Install these manually or install an AUR helper first:${NC}"
    echo "  • hyprls (Hyprland LSP)"
    echo "  • pyright (Python LSP - faster than pip)"
    echo "  • alejandra-bin (Nix formatter)"
    echo "  • prettierd (Prettier daemon)"
    echo ""
    echo "To install yay: pacman -S yay"
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
