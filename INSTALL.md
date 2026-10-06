# bugsvim Installation Guide

Quick setup for bugsvim on Linux distributions (Debian/Ubuntu, Arch, Fedora, openSUSE, Gentoo, Alpine, Bazzite), BSD (FreeBSD, OpenBSD, NetBSD), and Windows.

## Automated Installation (Recommended)

Run the unified installer to auto-detect your distribution:

```bash
bash install.sh
```

You can also pass flags for specific tasks or overrides:
```bash
# Check and install missing dependencies only
bash install.sh -d

# Run update pipeline (sync config, check tree-sitter-cli, clean legacy caches)
bash install.sh -u

# Update the nvim config itself from the repo (new plugins, prune removed files)
bash install.sh -c

# Specify distro explicitly (e.g., on Zorin, Pop!_OS, or Linux Mint)
bash install.sh --distro debian

# List supported distribution keys
bash install.sh --list-distros
```

Alternatively, invoke a distro driver directly from `installers/` (for example `bash installers/install-debian.sh`):

### Windows (PowerShell)

```powershell
# Fresh install (copies config)
.\install-windows.ps1

# Full install with dependencies (winget, build tools, LSPs, formatters)
.\install-windows.ps1 -InstallDeps

# Update existing install (sync config, clean legacy TS cache, ensure tree-sitter CLI)
.\install-windows.ps1 -Update

# Check and install missing dependencies only
.\install-windows.ps1 -Deps
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

Debian/Ubuntu package neither `lua-language-server`, `bash-language-server`, `nil`, `alejandra`, `prettier` nor `stylua`, and `apt-get` aborts the whole install when one name is unavailable. Get those from npm/upstream instead — `installers/install-debian.sh` does this automatically (including `lua-language-server` from its upstream release).

```bash
sudo apt-get update && sudo apt-get install -y \
  neovim git ripgrep fd-find curl build-essential pkg-config \
  lua-check luarocks python3-pip nodejs npm clang clang-tools \
  rustup shfmt clang-format && \
npm install -g bash-language-server @fsouza/prettierd vscode-langservers-extracted && \
pip3 install --user ruff pyright
```

### Full Setup Script
```bash
#!/bin/bash
set -euo pipefail

echo "=== bugsvim Debian Setup ==="

# System packages (apt-get aborts everything when a name is unavailable, and
# Debian/Ubuntu package neither lua-language-server, bash-language-server, nil,
# alejandra, prettier nor stylua)
sudo apt-get update
sudo apt-get install -y \
  neovim git ripgrep fd-find curl build-essential pkg-config \
  lua-check luarocks python3-pip nodejs npm clang clang-tools \
  rustup shfmt clang-format

# Global npm packages (bash-language-server, prettier daemon, web LSPs)
npm install -g bash-language-server @fsouza/prettierd vscode-langservers-extracted

# Python packages
pip3 install --user ruff pyright

# Optional: convenience tools (lazygit is not in the Ubuntu 24.04 repos)
sudo apt-get install -y bat wl-clipboard || true

# lua-language-server is not packaged: use the upstream release
# https://github.com/LuaLS/lua-language-server/releases

echo "✓ Setup complete!"
echo "Note: hyprls requires manual build from https://github.com/hyprwm/hyprland"
```

## Arch Linux

### One-liner (Core + Formatters)
```bash
sudo pacman -S --noconfirm \
  neovim git ripgrep fd curl base-devel pkg-config \
  lua-language-server luacheck luarocks python nodejs npm clang \
  bash-language-server rustup stylua shfmt clang prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted
```

### With AUR Support
```bash
#!/bin/bash
set -euo pipefail

echo "=== bugsvim Arch Setup ==="

# Core system packages (nil is not packaged for Arch; build it from https://github.com/oxalica/nil)
sudo pacman -S --noconfirm \
  neovim git ripgrep fd curl base-devel pkg-config \
  lua-language-server python nodejs npm clang \
  bash-language-server rustup stylua shfmt clang prettier

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
| luacheck | Lua linter/checker |
| luarocks | Lua package manager |
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

Fedora packages neither `stylua`, `lazygit`, `lua-language-server`, nor `shfmt`, so enable the COPRs used by the installer (`shfmt` comes from `vgaetera/extras`; if that COPR has no build for your release, fall back to `go install mvdan.cc/sh/v3/cmd/shfmt@latest`).

```bash
sudo dnf copr enable -y relativesure/all-packages
sudo dnf copr enable -y atim/lazygit
sudo dnf copr enable -y yorickpeterse/stylua
sudo dnf copr enable -y vgaetera/extras

sudo dnf update -y && sudo dnf install -y \
  neovim git ripgrep fd curl @development-tools pkg-config \
  lua luarocks lua-language-server python3-devel python3-pip nodejs npm clang \
  clang-tools-extra rust golang stylua shfmt lazygit bat wl-clipboard && \
sudo luarocks install luacheck && \
npm install -g bash-language-server @fsouza/prettierd vscode-langservers-extracted && \
pip3 install --user ruff pyright
```

### Full Setup Script
```bash
#!/bin/bash
set -euo pipefail

echo "=== bugsvim Fedora Setup ==="

# COPRs: Fedora does not package stylua, lazygit, lua-language-server, or shfmt
sudo dnf copr enable -y relativesure/all-packages
sudo dnf copr enable -y atim/lazygit
sudo dnf copr enable -y yorickpeterse/stylua
sudo dnf copr enable -y vgaetera/extras

# System packages (an unavailable name makes dnf abandon the entire
# transaction, so --skip-unavailable is used in the installer)
sudo dnf update -y
sudo dnf install -y \
  neovim git ripgrep fd curl @development-tools pkg-config \
  lua luarocks lua-language-server python3-devel python3-pip nodejs npm clang \
  clang-tools-extra rust golang stylua shfmt lazygit bat wl-clipboard

# shfmt (Bash formatter) built from source into ~/.local/bin if the
# vgaetera/extras COPR has no build for this release
command -v shfmt >/dev/null || go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Lua linter
sudo luarocks install luacheck || true

# Global npm packages
npm install -g bash-language-server @fsouza/prettierd vscode-langservers-extracted

# Python packages
pip3 install --user ruff pyright

echo "✓ Setup complete!"
echo "Note: hyprls requires manual build from https://github.com/hyprwm/hyprland"
```

## Next Steps

1. Clone bugsvim config: `git clone https://github.com/ddubs/bugsvim ~/.config/nvim`
2. Launch neovim: `nvim`
3. Plugins auto-install on first launch (lazy.nvim)
4. Run `:checkhealth` to verify LSP servers
