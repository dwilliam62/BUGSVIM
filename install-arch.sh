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

# Error tracking
FAILED_PACKAGES=()
FAILED_NPM=()
FAILED_PYTHON=()
FAILED_AUR=()

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
echo -e "${BLUE}║   bugsvim - Arch Linux Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check NeoVim version
echo -e "${BLUE}Checking NeoVim version...${NC}"
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}✗ NeoVim is not installed${NC}"
    echo -e "${RED}This configuration requires NeoVim to be installed first${NC}"
    echo -e "${RED}Install NeoVim with: sudo pacman -S neovim${NC}"
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
    echo -e "${YELLOW}Please upgrade NeoVim: sudo pacman -Syyu neovim${NC}"
    exit 1
fi

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
    python-pip \
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


echo -e "${BLUE}Step 4: Installing formatters and Python tools...${NC}"
sudo pacman -S --needed --noconfirm \
    stylua \
    shfmt \
    clang \
    prettier \
    pyright \
    ruff

echo -e "${BLUE}Step 5: Installing optional convenience tools...${NC}"
sudo pacman -S --needed --noconfirm \
    lazygit \
    bat \
    wl-clipboard || true

echo -e "${BLUE}Step 5b: Configuring npm for user installs...${NC}"
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗${NC} npm not found - skipping npm configuration"
    FAILED_PACKAGES+=("npm")
else
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global' --location=per-user 2>/dev/null || true
    export PATH=~/.npm-global/bin:$PATH
fi

echo -e "${BLUE}Step 6: Installing npm global packages...${NC}"
if command -v npm &> /dev/null; then
    npm install -g @fsouza/prettierd vscode-langservers-extracted || {
        FAILED_NPM+=("@fsouza/prettierd" "vscode-langservers-extracted")
        echo -e "${YELLOW}Warning: npm package installation failed${NC}"
    }
else
    echo -e "${RED}✗${NC} npm not available - skipping npm global packages"
    FAILED_NPM+=("@fsouza/prettierd" "vscode-langservers-extracted")
fi

echo -e "${YELLOW}Note: lua-language-server must be installed separately${NC}"
echo -e "${YELLOW}Install from: https://github.com/LuaLS/lua-language-server/releases${NC}"
echo -e "${YELLOW}Add to PATH: export PATH=\"${HOME}/.config/lsp/lua-language-server/bin:\$PATH\"${NC}"

# Python packages (pyright, ruff) are now installed via pacman in Step 4

echo -e "${BLUE}Step 7: Checking for AUR helper...${NC}"
if command -v yay &> /dev/null; then
    echo -e "${GREEN}✓ yay found${NC}"
    echo -e "${BLUE}Step 8: Installing AUR packages (recommended)...${NC}"
    yay -S --noconfirm hyprls alejandra-bin prettierd || {
        FAILED_AUR+=("hyprls" "alejandra-bin" "prettierd")
        echo -e "${YELLOW}Warning: Some AUR packages failed to install${NC}"
    }
elif command -v paru &> /dev/null; then
    echo -e "${GREEN}✓ paru found${NC}"
    echo -e "${BLUE}Step 8: Installing AUR packages (recommended)...${NC}"
    paru -S --noconfirm hyprls alejandra-bin prettierd || {
        FAILED_AUR+=("hyprls" "alejandra-bin" "prettierd")
        echo -e "${YELLOW}Warning: Some AUR packages failed to install${NC}"
    }
else
    echo -e "${YELLOW}⚠ No AUR helper found (yay/paru)${NC}"
    FAILED_AUR+=("hyprls" "alejandra-bin" "prettierd")
    echo -e "${YELLOW}Install these manually or install an AUR helper first:${NC}"
    echo "  • hyprls (Hyprland LSP)"
    echo "  • alejandra-bin (Nix formatter)"
    echo "  • prettierd (Prettier daemon)"
    echo ""
    echo "To install yay: pacman -S yay"
fi

echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Step 9: Verifying installation...${NC}"
echo ""

MISSING=0

echo "Checking LSP servers:"
for cmd in lua-language-server clangd; do
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
echo "Checking Python language tools:"
for cmd in pyright ruff; do
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

if [ ${#FAILED_AUR[@]} -gt 0 ]; then
    echo -e "${RED}AUR packages not installed (no AUR helper or installation failed):${NC}"
    for pkg in "${FAILED_AUR[@]}"; do
        echo "  • $pkg"
    done
    echo ""
fi

if [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ] && [ ${#FAILED_AUR[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Installation completed successfully!${NC}"
else
    if [ $MISSING -eq 0 ] && [ ${#FAILED_PACKAGES[@]} -eq 0 ] && [ ${#FAILED_NPM[@]} -eq 0 ] && [ ${#FAILED_PYTHON[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ Installation mostly successful, but AUR packages require manual setup${NC}"
    else
        echo -e "${YELLOW}⚠ Installation completed with some issues (see above)${NC}"
    fi
    echo -e "${YELLOW}However, bugsvim config has been installed to ~/.config/nvim${NC}"
    echo -e "${YELLOW}You can install missing components manually if needed${NC}"
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
echo "  4. Verify LSP: :checkhealth vim.lsp (or :LspInfo if using nvim-lspconfig)"
echo ""
echo "See POST-INSTALL.md for additional setup and troubleshooting."
