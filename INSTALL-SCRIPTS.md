# bugsvim Installation Scripts

Automated installation scripts for bugsvim on Arch Linux, Debian/Ubuntu, and Fedora.

## Quick Start

Choose your distribution and run the corresponding script:

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

## What the Scripts Do

Each script performs the following steps in order:

1. **Backup Existing Config** - Backs up existing NeoVim configuration if found
   - Checks: `~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim`
   - Creates timestamped backup: `~/neovim-backup-YYYYMMDD-HHMMSS/`
   - Prompts user before backing up (optional)
2. **Verify Distribution** - Checks you're running the correct OS (with override option)
3. **Update Package Manager** - Updates package lists
4. **Install Core Dependencies** - neovim, git, ripgrep, fd, build tools, pkg-config
5. **Install Language Servers** - lua-language-server, python, nodejs, npm, clang, bash-language-server, rustup, nil
6. **Install Formatters** - stylua, shfmt, clang-format, prettier
7. **Install Convenience Tools** - lazygit, bat, wl-clipboard (optional)
8. **Install Global Packages** - npm packages (@fsouza/prettierd, vscode-langservers-extracted)
9. **Install Python Packages** - pip packages (ruff, pyright)
10. **Optional: Build hyprls** - Prompts to build Hyprland LSP from source (Debian/Fedora only)
11. **Verify Installation** - Checks all components are installed and accessible

## Distro-Specific Notes

### Arch Linux (`install-arch.sh`)

**Features:**
- Supports both `yay` and `paru` AUR helpers
- Automatically installs AUR packages if helper is found:
  - hyprls
  - pyright
  - alejandra-bin
  - prettierd

**Prerequisites:**
- `sudo` access
- Optional: AUR helper (yay or paru)

**Installation Time:** ~5-10 minutes

---

### Debian/Ubuntu (`install-debian.sh`)

**Features:**
- Interactive option to build hyprls from source
- Graceful fallback if hyprls build fails
- Installs latest packages from debian repos

**Prerequisites:**
- `sudo` access
- build-essential for hyprls compilation (optional)

**Special Handling:**
- Includes lua5.1 for Lua development
- Uses python3-venv for Python environments
- fd-find package (not just fd)
- rustup for latest Rust

**Installation Time:** ~8-15 minutes (depending on hyprls build)

---

### Fedora (`install-fedora.sh`)

**Features:**
- Uses `dnf` package manager
- Includes development-tools group
- Initializes Rust toolchain automatically
- Interactive hyprls build option

**Prerequisites:**
- `sudo` access
- @development-tools group

**Special Handling:**
- Uses clang-tools-extra instead of clang-tools
- Uses python3-devel for Python development
- Uses @development-tools meta-package for build tools
- Automatic Rust initialization

**Installation Time:** ~8-15 minutes (depending on hyprls build)

---

## Backup Feature

Each script automatically checks for existing NeoVim configurations and offers to back them up before installation.

### What Gets Backed Up

If any of these directories exist, they will be backed up:
- `~/.config/nvim` - Configuration files
- `~/.local/share/nvim` - Plugin data and runtime files
- `~/.local/state/nvim` - Session state and history

### Backup Location

Backups are stored in:
```
~/neovim-backup-YYYYMMDD-HHMMSS/
```

Example: `~/neovim-backup-20251218-005700/`

Within the backup directory, each location is preserved:
```
neovim-backup-20251218-005700/
├── .config-nvim/          # From ~/.config/nvim
├── .local-share-nvim/     # From ~/.local/share/nvim
└── .local-state-nvim/     # From ~/.local/state/nvim
```

### Restoring a Backup

If needed, you can restore your backup:
```bash
# List backups
ls ~/ | grep neovim-backup

# Restore a specific backup
cp -r ~/neovim-backup-20251218-005700/.config-nvim ~/.config/nvim
cp -r ~/neovim-backup-20251218-005700/.local-share-nvim ~/.local/share/nvim
cp -r ~/neovim-backup-20251218-005700/.local-state-nvim ~/.local/state/nvim
```

## Usage Examples

### Run with auto-detection (recommended)
```bash
bash install-arch.sh
```

### Run on non-native distro (with confirmation)
```bash
# Run Debian script on Ubuntu - will ask for confirmation
bash install-debian.sh
```

### Skip hyprls build (Debian/Fedora)
When prompted "Build hyprls from source? (y/n)", press 'n'

### Build hyprls from source
When prompted "Build hyprls from source? (y/n)", press 'y'

## Troubleshooting

### Script Exits with Distro Mismatch
The script detected you're not on the expected distro. If you want to continue anyway, answer 'y' to the confirmation prompt.

### Some Components Missing After Install
Check the verification output at the end. You may need to:

1. **Missing lua-language-server:**
   ```bash
   # Debian/Ubuntu
   sudo apt-get install lua-language-server
   
   # Fedora
   sudo dnf install lua-language-server
   
   # Arch
   sudo pacman -S lua-language-server
   ```

2. **Missing pyright:**
   ```bash
   pip3 install --user pyright
   ```

3. **Missing npm packages:**
   ```bash
   npm install -g @fsouza/prettierd vscode-langservers-extracted
   ```

4. **hyprls not available:**
   Build from source:
   ```bash
   git clone https://github.com/hyprwm/hyprland /tmp/hyprland
   cd /tmp/hyprland
   make hyprls
   sudo cp hyprls /usr/local/bin/
   ```

### npm: command not found
Node.js/npm not installed. Install manually:

**Arch:**
```bash
sudo pacman -S nodejs npm
```

**Debian:**
```bash
sudo apt-get install nodejs npm
```

**Fedora:**
```bash
sudo dnf install nodejs npm
```

### Permission denied when running script
Make the script executable:
```bash
chmod +x install-arch.sh  # or install-debian.sh, install-fedora.sh
bash install-arch.sh
```

## Advanced: Manual Installation

If you prefer to install manually, see:
- `INSTALL.md` - Detailed manual installation instructions per distro
- `PACKAGES.txt` - Copy-paste package lists

## Verification After Installation

After the script completes successfully, verify everything works:

```bash
# Check specific LSP servers
which lua-language-server
which clangd
which pyright

# Check formatters
which stylua
which shfmt

# Check npm packages are installed globally
npm list -g @fsouza/prettierd

# Launch NeoVim and check LSP status
nvim
:LspInfo

# Or run NeoVim health check
nvim --headless -c 'checkhealth' -c 'qa'
```

## Next Steps After Installation

1. **Clone bugsvim configuration:**
   ```bash
   git clone https://github.com/ddubs/bugsvim ~/.config/nvim
   ```

2. **Launch NeoVim:**
   ```bash
   nvim
   ```
   
   On first launch, lazy.nvim will automatically install all plugins.

3. **Verify LSP servers:**
   ```vim
   :LspInfo
   ```

4. **Check overall health:**
   ```vim
   :checkhealth
   ```

5. **Start editing!**

## Script Maintenance

The scripts are designed to be idempotent - you can run them multiple times without issues. They will:
- Update existing packages
- Skip already-installed packages
- Re-verify all components

## Support

If you encounter issues:

1. Check the distro-specific notes above
2. Review troubleshooting section
3. Check INSTALL.md for detailed instructions
4. Verify you have `sudo` access
5. Ensure you're on a supported distribution

## Environment Variables

The scripts respect these environment variables if set:

```bash
# Disable interactive prompts (for hyprls build on Debian/Fedora)
# Set to "n" to skip hyprls, "y" to build
INTERACTIVE=n bash install-debian.sh

# Set a custom npm prefix (if using custom npm setup)
# export NPM_CONFIG_PREFIX=~/.npm-global
```

## Permissions

Scripts require `sudo` access for package installation. They will NOT:
- Modify system files outside of package management
- Create files in your home directory
- Change your shell or environment

## License

These scripts are part of bugsvim and follow the same license.
