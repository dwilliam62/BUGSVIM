# 📋 bugsvim Changelog

> ** ✨ A comprehensive history of changes, improvements, and updates to
> bugsvim**

---

# 🚀 **Current Release - v1.0.2**

#### 📅 **Updated: December 23st, 2025**

- Added:
  - Install script for gentoo
    - First pass

#### 📅 **Updated: December 21st, 2025**

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
