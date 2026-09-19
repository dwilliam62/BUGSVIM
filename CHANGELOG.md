# 📋 bugsvim Changelog

> ** ✨ A comprehensive history of changes, improvements, and updates to
> bugsvim**

---

# 🚀 **Current Release - v1.0.5**

#### 📅 **Updated: Sept, 2026**

- Arch reported bash-server not installed
  - It only checked via `npm`
  - Fixed check for Arch via pacman
- Huge refactor
  - `install.sh` root installer script
  - Calls distro specific installer code
  - About 50% reduction vs. individual per-distro scripts
  - Common functions lib/common.sh
- Added `-u` to update to nvim v12.x+
- Added checks/install for `luacheck/luarock`
- Added `--deps` to check for all needed pkgs and install

#### 📅 **Updated: August, 2026**

- Updated bash scripts for `env`
- Removed neovim from install scripts
- Added json/jsonc formatters
- Added `jq` to deps
- Fixed stall after hyprls install

#### 📅 **Updated: April, 2026**

- Added:
  - Install script for Bazzite linux

#### 📅 **Updated: January, 2026**

- Added:
  - Install script for Alpine linux

#### 📅 **Updated: December, 2025**

- Added:
  - Install script for gentoo
    - First pass

- 🛠️ Fixed:
  - `blink-cmp` set defaults for completion
    - `tab`, `alt-tab`, `cr`
  - Inline diagnostics
    - Fix virtual_text severity config to properly show inline diagnostics
    - Changed from 'severity = HINT' to 'severity = {min = HINT}'
    - Rename cursor diagnostics keymap from `<leader>Dc` to `<leader>cd`
      - Avoids confusion with debug menu which uses `<leader>d\*`` keybinds
  - `hyprls` build process
  - Markdown preview failed build, modified build order

  - 🚀 Added:
    - 📝 Documentaion
      - Keybinds
      - Markdown LSP preview
      - Install scripts
