# bugsvim — Modern NeoVim Configuration

<img src="/assets/preview.png" width="100%" />
<img src="/assets/preview2.png" width="100%" />
<img src="/assets/preview3.png" width="100%" />
<img src="/assets/preview4.png" width="100%" />

## About

bugsvim is a thoughtfully curated NeoVim configuration built for modern development workflows. It combines the power of Lua-based configuration with a carefully selected collection of plugins to provide a fast, extensible, and enjoyable editing experience.

### Acknowledgments

This configuration is forked from **[BUGSVIM](https://github.com/Abhra00/BUGSVIM)** by [Abhra00](https://github.com/Abhra00). We are grateful for the excellent foundation and extend our thanks to:

- **Abhra00** for the original BUGSVIM project
- **folke** and the **lazy.nvim** team for the exceptional plugin manager
- **nvim-treesitter** contributors for intelligent syntax parsing
- All maintainers of the plugins integrated into this configuration

## Features

### 🎨 Beautiful & Responsive

- **Tokyo Night** colorscheme with carefully tuned defaults
- Dynamic statusline via **lualine** showing real-time editor information
- Smart session persistence that survives restarts
- Smooth animations and visual feedback

### 🧠 Intelligent Development

- **Complete LSP ecosystem** with support for:
  - Lua (lua-language-server)
  - Python (Pyright + Ruff)
  - TypeScript/JavaScript (ts_ls)
  - C/C++ (clangd)
  - Rust (rust-analyzer)
  - Bash (bash-language-server)
  - HTML, CSS, Tailwind CSS
  - Hyprland (hyprls)
  - Java (JDTLS)
- **Enhanced diagnostics** with inline error messages, gutter signs, and floating windows
- **Advanced code completion** via Blink Cmp with intelligent caching
- **Multi-formatter support** via Conform (stylua, shfmt, clang-format, prettier)
- **Real-time linting** with nvim-lint
- **Interactive debugging** support via nvim-dap

### 🚀 Productivity

- **Treesitter-powered** syntax highlighting and text objects
- **Fast fuzzy finding** and navigation
- **Git integration** with gitsigns for inline blame and diff hunks
- **Task & TODO tracking** with todo-comments
- **Smart snippets** for rapid coding
- **Lazy loading** for sub-millisecond startup times
- **Which-key** integration for discoverable keybindings
- **Beautiful UI with Noice.nvim** - command palette and event notifications in popup windows

### 🛠️ Developer Tools

- **Spring Boot** development support
- **Java Development** via JDTLS
- **Markdown support** with live preview in browser (markdown-preview.nvim)
- **Enhanced markdown editing** with checkbox and table support (markdown.nvim)
- **Snacks.nvim** for notifications, animations, and quality-of-life features
- **Mini.nvim** utilities for enhanced editing
- **LazyDev** for integrated Neovim API documentation

### ✨ Extra Polish

- Persistent undo history
- Auto-formatting on save
- Smart keybindings
- Graceful error handling

## Installation

### Quick Install (Recommended)

bugsvim provides automated installation scripts for major Linux distributions:

#### Arch Linux

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-arch.sh
```

#### Debian/Ubuntu

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-debian.sh
```

#### Fedora

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-fedora.sh
```

**The installation scripts will:**

- Detect your distribution
- Backup your existing NeoVim configuration
- Install all required system packages and language servers
- Configure npm with user-level permissions
- Verify the complete installation
- Copy the configuration to `~/.config/nvim`

See [INSTALL.md](./INSTALL.md) for manual installation steps.

## Required Packages

### Core Dependencies

| Package                                      | Purpose                  |
| -------------------------------------------- | ------------------------ |
| **neovim**                                   | Text editor              |
| **git**                                      | Version control          |
| **ripgrep**                                  | Fast file search         |
| **fd**                                       | Fast directory traversal |
| **curl**                                     | Network requests         |
| **build-essential** / **@development-tools** | C/C++ compilation        |
| **pkg-config**                               | Development libraries    |

### Language Servers (LSP)

| LSP                      | Language(s)           | Installation       |
| ------------------------ | --------------------- | ------------------ |
| **lua-language-server**  | Lua                   | System package     |
| **clangd**               | C/C++                 | System package     |
| **pyright**              | Python                | pip3 or AUR        |
| **ts_ls**                | TypeScript/JavaScript | Npm                |
| **rust-analyzer**        | Rust                  | System package     |
| **bash-language-server** | Bash/Shell            | Npm                |
| **html**                 | HTML                  | Npm                |
| **cssls**                | CSS                   | Npm                |
| **tailwindcss**          | Tailwind CSS          | Npm                |
| **hyprls**               | Hyprland Config       | AUR / Manual build |
| **JDTLS**                | Java                  | Npm                |

### Code Formatters

| Formatter        | Language(s)       | Installation   |
| ---------------- | ----------------- | -------------- |
| **stylua**       | Lua               | System package |
| **shfmt**        | Shell/Bash        | System package |
| **clang-format** | C/C++             | System package |
| **prettier**     | Web (JS/CSS/HTML) | Npm            |
| **prettierd**    | Web (daemon mode) | Npm            |

### Optional Utilities

| Tool             | Purpose                    | Installation   |
| ---------------- | -------------------------- | -------------- |
| **lazygit**      | Git UI client              | System package |
| **bat**          | Better `cat`               | System package |
| **wl-clipboard** | Clipboard access (Wayland) | System package |

## First Run

After installation:

```bash
# Reload your shell to apply PATH changes
source ~/.$(basename $SHELL)rc

# Launch NeoVim
nvim

# Plugins will auto-install on first launch
# Verify LSP status: :LspInfo
# Check health: :checkhealth
```

For detailed post-installation setup, see [POST-INSTALL.md](./POST-INSTALL.md).

## Configuration Structure

All configuration is organized in `~/.config/nvim/lua/`:

```
nvim/
├── init.lua              # Entry point
└── lua/
    ├── config/           # Core configuration
    │   ├── options.lua   # Editor options & settings
    │   ├── keymaps.lua   # Key bindings
    │   ├── lazy.lua      # Plugin manager setup
    │   ├── autocmds.lua  # Auto commands
    │   └── globals.lua   # Global variables
    ├── plugins/          # Plugin specifications
    ├── servers/          # LSP configurations
    └── utils/            # Utility functions
```

## Troubleshooting

For common issues and solutions, see [POST-INSTALL.md](./POST-INSTALL.md).

## License

This project is licensed under the **GNU General Public License v3 (GPL-3.0)**.

You are free to:

- Use this software for any purpose
- Distribute copies
- Modify the source code

Under the condition that:

- You provide source code availability (include it or link to it)
- Any modified versions must also use GPL-3.0
- You include the license and copyright notices

See the [LICENSE](./LICENSE) file for the full text.

## Support

For issues or contributions, visit the [GitHub repository](https://github.com/dwilliam62/bugsvim).
