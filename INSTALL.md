# bugsvim Installation Guide

Quick setup for bugsvim on Debian/Ubuntu, Arch Linux, and Fedora.

## Automated Installation (Recommended)

Use the provided installation scripts for your distro:

### Arch Linux
```bash
bash install-arch.sh
```

### Debian/Ubuntu
```bash
bash install-debian.sh
```

### Fedora
```bash
bash install-fedora.sh
```

These scripts will:
- Detect your distribution
- Install all packages and language servers
- Install npm and pip packages
- Verify the installation
- Display next steps

---

## Manual Installation

### Debian/Ubuntu

### One-liner (Core + Formatters)
```bash
sudo apt-get update && sudo apt-get install -y \
  neovim git ripgrep fd-find curl build-essential pkg-config \
  lua-language-server python3-pip nodejs npm clang clang-tools \
  bash-language-server rustup nil stylua shfmt clang-format prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted && \
pip3 install --user ruff pyright
```

### Full Setup Script
```bash
#!/bin/bash
set -euo pipefail

echo "=== bugsvim Debian Setup ==="

# System packages
sudo apt-get update
sudo apt-get install -y \
  neovim git ripgrep fd-find curl build-essential pkg-config \
  lua-language-server python3-pip nodejs npm clang clang-tools \
  bash-language-server rustup nil stylua shfmt clang-format prettier

# Global npm packages
npm install -g @fsouza/prettierd vscode-langservers-extracted

# Python packages
pip3 install --user ruff pyright

# Optional: convenience tools
sudo apt-get install -y lazygit bat wl-clipboard || true

echo "✓ Setup complete!"
echo "Note: hyprls requires manual build from https://github.com/hyprwm/hyprland"
```

## Arch Linux

### One-liner (Core + Formatters)
```bash
sudo pacman -S --noconfirm \
  neovim git ripgrep fd curl base-devel pkg-config \
  lua-language-server python nodejs npm clang \
  bash-language-server rustup nil stylua shfmt clang prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted
```

### With AUR Support
```bash
#!/bin/bash
set -euo pipefail

echo "=== bugsvim Arch Setup ==="

# Core system packages
sudo pacman -S --noconfirm \
  neovim git ripgrep fd curl base-devel pkg-config \
  lua-language-server python nodejs npm clang \
  bash-language-server rustup nil stylua shfmt clang prettier

# Global npm packages
npm install -g @fsouza/prettierd vscode-langservers-extracted

# AUR packages (requires yay/paru)
if command -v yay &> /dev/null; then
  echo "Installing AUR packages..."
  yay -S --noconfirm hyprls pyright alejandra-bin
else
  echo "⚠ yay not found. Install manually:"
  echo "  - hyprls"
  echo "  - pyright"
  echo "  - alejandra-bin"
fi

# Optional: convenience tools
sudo pacman -S --noconfirm lazygit bat wl-clipboard || true

echo "✓ Setup complete!"
```

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| neovim | Editor |
| git | Version control |
| ripgrep, fd | Fuzzy search/navigation |
| lua-language-server | Lua LSP |
| python3, pip3 | Python & pyright |
| nodejs, npm | Node runtime & npm packages |
| clang, clang-tools | C/C++ compiler & clangd |
| bash-language-server | Bash LSP |
| rustup | Rust toolchain |
| nil | Nix LSP |
| stylua | Lua formatter |
| shfmt | Bash formatter |
| clang-format | C/C++ formatter |
| prettier | Web formatter |
| @fsouza/prettierd | Prettier daemon (faster) |
| vscode-langservers-extracted | HTML, CSS LSP |

## Minimal Installation

If space is constrained, only install:
```bash
# Debian
sudo apt-get install -y neovim git ripgrep fd-find nodejs npm python3-pip

# Arch
sudo pacman -S --noconfirm neovim git ripgrep fd nodejs npm python
```

Then install formatters/LSPs on-demand as you need them.

## Verification

After installation, verify everything works:

```bash
# Check LSP servers
lua-language-server --version
clangd --version
pyright --version

# Check npm packages
npm list -g @fsouza/prettierd

# Launch neovim and check health
nvim --headless -c 'checkhealth' -c 'qa'
```

## Troubleshooting

**hyprls not found on Debian:**
- Build from source: `git clone https://github.com/hyprwm/hyprland && cd hyprland && make hyprls`
- Or skip if not using Hyprland configs

**pyright/ruff not available:**
- Install via pip: `pip3 install --user pyright ruff`

**npm packages not in PATH:**
- Add to your shell profile: `export PATH="$HOME/.npm/bin:$PATH"`

**Arch: AUR packages missing:**
- Install an AUR helper: `pacman -S yay` or `pacman -S paru`

### Fedora

### One-liner (Core + Formatters)
```bash
sudo dnf update -y && sudo dnf install -y \
  neovim git ripgrep fd curl @development-tools pkg-config \
  lua lua-language-server python3-devel python3-pip nodejs npm clang \
  clang-tools-extra bash-language-server rust nil stylua shfmt prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted && \
pip3 install --user ruff pyright
```

### Full Setup Script
```bash
#!/bin/bash
set -euo pipefail

echo "=== bugsvim Fedora Setup ==="

# System packages
sudo dnf update -y
sudo dnf install -y \
  neovim git ripgrep fd curl @development-tools pkg-config \
  lua lua-language-server python3-devel python3-pip nodejs npm clang \
  clang-tools-extra bash-language-server rust nil stylua shfmt prettier

# Global npm packages
npm install -g @fsouza/prettierd vscode-langservers-extracted

# Python packages
pip3 install --user ruff pyright

# Initialize Rust
rustup default stable || true

# Optional: convenience tools
sudo dnf install -y lazygit bat wl-clipboard || true

echo "✓ Setup complete!"
echo "Note: hyprls requires manual build from https://github.com/hyprwm/hyprland"
```

## Next Steps

1. Clone bugsvim config: `git clone https://github.com/ddubs/bugsvim ~/.config/nvim`
2. Launch neovim: `nvim`
3. Plugins auto-install on first launch (lazy.nvim)
4. Run `:checkhealth` to verify LSP servers
