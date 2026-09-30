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
- All distro installers: package installs are resilient now
  - `apt`, `dnf`, `zypper`, `pacman`, `apk`, `emerge`, `pkg`, `pkgin` and `pkg_add` resolve the entire argument list before installing, so a single unavailable name aborted the transaction and installed *nothing* (verified in containers)
  - New shared `install_packages_resilient` helper in `lib/common.sh`: install the batch first, then retry one package at a time so the resolvable packages still land and only genuinely unavailable names are reported
  - `install-fedora.sh` and `install-bazzite.sh` now use the same helper (dnf keeps `--skip-unavailable` as a first pass)
- Package audit fixes (each previously aborted its whole transaction)
  - openSUSE: `luarocks` -> `lua54-luarocks` (openSUSE only ships versioned luarocks packages)
  - Alpine: dropped `lua5.1-luacheck` and `py3-pyright` (neither exists; pyright comes from pip)
  - Gentoo: `dev-ruby/pkg-config` -> `dev-util/pkgconf`, added `llvm-core/clang`, moved overlay-only tools to guarded steps, and enables the GURU overlay
  - Debian/Ubuntu: `lua-language-server` is not packaged, so it is installed from the upstream release into `~/.local`
  - Docs: Debian/Ubuntu and Arch one-liners no longer list packages those repositories do not provide (`lua-language-server`, `bash-language-server`, `nil`, `alejandra`, `prettier`, `stylua`, `lazygit`)
- BSD installers validated on real FreeBSD 15, OpenBSD 7.8 and NetBSD 11 VMs
  - `run_as_root` now probes which privilege tool actually works: FreeBSD ships `doas` with `permit persist :wheel`, which prompted for a password and aborted the whole run even though `sudo` was passwordless
  - FreeBSD: `lua`, `lua-luarocks`, `lua-luacheck`, `lua51-luacheck` and `py3-pip` do not exist; uses `lua54`, `lua54-luarocks`, `lua54-luacheck`, plus native `ruff` and `py<ver>-pyright` with pip as fallback
  - OpenBSD: dropped `pkgconf`, `npm` (the node package provides it) and `lazygit` (not packaged), fixed `luarocks--lua51` -> `luarocks-lua54`, and added `clang-tools-extra` (provides unversioned clangd/clang-format) and `lua-language-server`
  - All three BSD scripts now install ruff/pyright (previously missing entirely) and pass `--break-system-packages`, since BSD Python is marked externally managed
  - `update_treesitter_cli` sets `LIBCLANG_PATH` when libclang lives in a versioned llvm directory (`/usr/local/llvm*/lib`), which makes the cargo fallback succeed on OpenBSD (verified: tree-sitter-cli 0.27.0)
  - Package-install failures now log the package manager's own error line instead of a generic "unavailable"

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
