# 📋 bugsvim Changelog

> ** ✨ A comprehensive history of changes, improvements, and updates to
> bugsvim**

---

# 🚀 **Current Release - v1.0.6**

#### 📅 **Updated: Sept, 2026**

- Added: `netBSD` to supported distros (v11.x)
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
- Fedora reported `shfmt` and `clang` missing after `install.sh -d`
  - `dnf` resolves every argument before installing, so the unavailable `shfmt` name aborted the transaction and silently skipped `clang`, `clang-tools-extra`, `luarocks`, `lua-language-server`, `stylua`, `lazygit` and `python3-devel`
  - Installs now use `--skip-unavailable` with a per-package fallback, and unavailable names are reported instead of swallowed by `|| true`
  - Added the `vgaetera/extras` COPR as the `shfmt` source, with `go install mvdan.cc/sh/v3/cmd/shfmt@latest` as a fallback
- Bazzite installer: same all-or-nothing failure fixed
  - `rpm-ostree` aborts the whole layer on a single unknown name; missing names are now dropped, reported, and the rest are layered with a retry
  - Homebrew installs pre-filter formulae so one unknown formula no longer aborts the batch
  - Enables the relativesure/all-packages, atim/lazygit and vgaetera/extras COPRs (via `dnf copr`, or by writing a repo file on images with no copr plugin)
  - Added `lua-language-server`, uses `tree-sitter-cli` on the rpm-ostree path, and warns that layered packages need a reboot before they are usable
- Docs: Fedora sections of `INSTALL.md`, `INSTALL.es.md`, `PACKAGES.txt` and `INSTALL-SCRIPTS.md` (+`.es.md`) no longer list `shfmt` as a Fedora package and now enable the required COPRs

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
