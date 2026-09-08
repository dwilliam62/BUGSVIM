# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is **Tsukiyo NeoVim** (also referenced as **bugsvim**), a modern Lua-based NeoVim configuration using `lazy.nvim` as the plugin manager. The configuration targets NeoVim 0.10+ (including 0.11 and 0.12+) and provides a fully-featured development environment with LSP support, Treesitter highlighting/textobjects, auto-formatting, linting, debugging, UI utilities, and Git integration.

## Architecture

### Repository Structure

```
├── init.lua / nvim/init.lua  # Entry point - bootstraps lazy.nvim and loads config modules
├── nvim/
│   ├── .luacheckrc           # Luacheck linter configuration
│   ├── .luarc.json           # Lua-LS diagnostics configuration
│   ├── .stylua.toml          # StyLua formatter configuration (160 width, single quotes)
│   ├── init.lua              # Config entry point (requires config.lazy)
│   └── lua/
│       ├── config/           # Core NeoVim configuration
│       │   ├── autocmds.lua  # Autocommands (yank highlight, LSP attach callbacks)
│       │   ├── diagnostics.lua # Diagnostics appearance and float config
│       │   ├── globals.lua   # Global variables and leader keys
│       │   ├── keymaps.lua   # Key bindings (navigation, window splits, buffer management)
│       │   ├── lazy.lua      # lazy.nvim bootstrap and initialization
│       │   └── options.lua   # Editor options (indentation, search, folding, UI)
│       ├── plugins/          # Lazy-loaded plugin specifications
│       │   ├── blink-cmp.lua # Completion engine & snippet integration (LuaSnip)
│       │   ├── colortheme.lua # Tokyonight theme configuration
│       │   ├── conform.lua   # Auto-formatting engine (format-on-save)
│       │   ├── gitsigns.lua  # Git hunk signs and inline blame
│       │   ├── lazydev.lua   # Lua development configuration for Neovim API
│       │   ├── lualine.lua   # Status line
│       │   ├── markdown.lua  # Markdown enhancements (checkboxes, tables)
│       │   ├── markdown-preview.lua # In-browser live markdown preview
│       │   ├── mini-nvim.lua # Mini suite (pairs, surround, ai, comment, move, icons)
│       │   ├── noice.lua     # Experimental UI replacement (cmdline, messages)
│       │   ├── nvim-dap.lua  # DAP debugging client & UI
│       │   ├── nvim-lint.lua # Linter orchestration
│       │   ├── nvim-lspconfig.lua # LSP client integration
│       │   ├── nvim-treesitter.lua # Treesitter (main branch) & textobjects
│       │   ├── persistance.lua # Session persistence
│       │   ├── snacks.lua    # Snacks.nvim utilities (picker, explorer, notifier)
│       │   ├── todo-comments.lua # Todo/fixme highlight and search
│       │   └── which-key.lua # Interactive keybinding popup helper
│       ├── servers/          # LSP server configurations
│       │   ├── init.lua      # Central LSP bootstrap, capabilities, & server enablement
│       │   ├── bashls.lua    # Bash language server
│       │   ├── clangd.lua    # C/C++ language server
│       │   ├── cssls.lua     # CSS language server
│       │   ├── html.lua      # HTML language server
│       │   ├── hyprls.lua    # Hyprland config language server
│       │   ├── lua_ls.lua    # Lua language server
│       │   ├── nil_ls.lua    # Nix language server (Nil)
│       │   ├── pyright.lua   # Python language server
│       │   ├── rust_analyzer.lua # Rust language server
│       │   ├── tailwindcss.lua # Tailwind CSS language server
│       │   └── ts_ls.lua     # TypeScript / JavaScript language server
│       └── utils/            # Shared utilities
│           ├── diagnostics.lua # Diagnostic sign helpers
│           └── lsp.lua       # LSP attachment helpers and keymaps
├── install-alpine.sh         # Alpine Linux installation script
├── install-arch.sh           # Arch Linux installation script
├── install-bazzite.sh        # Bazzite (Fedora Atomic) installation script
├── install-debian.sh         # Debian / Ubuntu installation script
├── install-fedora.sh         # Fedora Linux installation script
├── install-freebsd.sh        # FreeBSD installation script
├── install-gentoo.sh         # Gentoo Linux installation script
├── install-openbsd.sh        # OpenBSD installation script
├── install-opensuse.sh       # OpenSUSE installation script
└── install-windows.ps1       # Windows PowerShell installation script
```

### Treesitter Architecture

- **`nvim-treesitter` (`main` branch)**:
  - Supports NeoVim 0.12+ (built-in treesitter highlighting with `vim.treesitter.start()`).
  - Requires the `tree-sitter` CLI installed on the system (`tree-sitter-cli` package or via cargo) for compiling language parsers with `:TSUpdate`.
- **`nvim-treesitter-textobjects` (`main` branch)**:
  - Direct Lua API keybindings for textobject selections (`af`/`if`, `ac`/`ic`, `aa`/`ia`), jumping movements (`]m`, `[m`, `]]`, `[[`), and parameter swapping (`<leader>a`, `<leader>A`).

### Installation & Update Scripts

Each `install-<distro>.sh` script provides both full installation and modular update modes:
- **Full Install**: `bash install-<distro>.sh`
- **Force Reinstall**: `bash install-<distro>.sh -f` / `--force`
- **Update Mode**: `bash install-<distro>.sh -u` / `--update`
  - Runs the `UPDATE_TASKS` pipeline.
  - Verifies and installs `tree-sitter-cli` if missing.
  - Cleans legacy `nvim-treesitter` caches from older `master` checkouts.
  - Syncs the updated `nvim/` config directory to `~/.config/nvim`.
- **Dependency Check & Install**: `bash install-<distro>.sh -d` / `--deps`
  - Checks for all required system packages, language servers, formatters, linters, npm packages, python packages, and luarocks tools.
  - Installs any missing dependencies.
  - Runs full verification.

### Plugin Manager: lazy.nvim

- **Bootstrap**: Automatically clones `lazy.nvim` to `~/.local/share/nvim/lazy/lazy.nvim` if not present.
- **Plugin specs**: Defined in `lua/plugins/` directory and auto-imported.
- **Color scheme**: Defaults to `tokyonight-night`.
- **Lockfile**: Managed at `lazy-lock.json` (`~/.config/nvim/lazy-lock.json`).

### LSP Architecture

LSP is managed through two layers:

1. **`lua/servers/init.lua`**: Central orchestration
   - Sets up default LSP capabilities and merges with `blink.cmp` capabilities.
   - Requires and initializes each language server module in `lua/servers/*.lua`.
   - Enables configured servers via `vim.lsp.enable()`.

2. **`lua/servers/*.lua`**: Individual server configurations
   - Configured with server-specific settings and attach callbacks.

### Formatter & Linter Configuration

**Conform.nvim** (formatting in `lua/plugins/conform.lua`):
- Format on save enabled (500ms timeout, fallback to LSP).
- Formatters:
  - Lua: `stylua`
  - Python: `ruff_format`
  - JavaScript / TypeScript: `prettierd`
  - C / C++: `clang-format`
  - Bash: `shfmt`
  - Web (HTML/CSS/JSON/YAML/Markdown): `prettierd`

**nvim-lint** (linting in `lua/plugins/nvim-lint.lua`):
- Lints on buffer save (`BufWritePost`).
- Linters:
  - JavaScript / TypeScript: `eslint_d`
  - Lua: `luacheck`
  - C / C++: `cpplint`
  - Rust: `clippy`
  - Python: `ruff`

## Common Commands

### Configuration & Code Quality

| Task | Command |
|------|---------|
| Edit NeoVim config | `nvim ~/.config/nvim/init.lua` (or `<leader>rc` inside NeoVim) |
| Format Lua files | `stylua nvim/lua/` (or in NeoVim: `<leader>cf`) |
| Check Lua code | `cd nvim && luacheck lua/` |
| Run Distro Update | `bash install-<distro>.sh -u` |

### Plugin & Treesitter Management

| Task | Command |
|------|---------|
| View installed plugins | `:Lazy` in NeoVim |
| Sync / Update plugins | `:Lazy sync` or `:Lazy update` |
| Update Treesitter parsers | `:TSUpdate` in NeoVim |
| Install parser manually | `:TSInstall <language>` |
| Check system health | `:checkhealth` in NeoVim |

### LSP Operations

| Keybinding | Action |
|-----------|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `gi` / `gI` | Go to implementation |
| `gy` | Go to type definition |
| `<leader>ca` | Code actions |
| `<leader>rn` / `<leader>cR` | Rename symbol / file |

## Development Practices

### Adding a New LSP Server

1. Create a new file `lua/servers/<server_name>.lua` following existing server patterns.
2. Export a function accepting `capabilities` that sets up the server.
3. Import and initialize the server in `lua/servers/init.lua`.
4. Add the server name to the `vim.lsp.enable()` table in `lua/servers/init.lua`.

### Adding a New Plugin

1. Create `lua/plugins/<plugin_name>.lua` with a `lazy.nvim` spec.
2. Return the spec table with repository, event/cmd/keys triggers, and `opts`/`config`.
3. `lazy.nvim` will automatically discover and load the file.

### Formatting Rules

- All Lua files must adhere to `.stylua.toml` (160 column width, single quotes, Unix line endings).
- Web and markdown files formatted using `prettierd` / `prettier`.
