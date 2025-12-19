# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is **Tsukiyo NeoVim**, a Lua-based NeoVim configuration using lazy.nvim as the plugin manager. The configuration provides a fully-featured development environment with LSP support, auto-formatting, linting, debugging, and Git integration.

## Architecture

### Directory Structure

```
nvim/
├── init.lua                  # Entry point - bootstraps lazy.nvim and loads config modules
├── lua/
│   ├── config/              # Core NeoVim configuration
│   │   ├── lazy.lua         # Plugin manager bootstrap and setup
│   │   ├── options.lua      # NeoVim editor settings (tabs, search, visual, behavior)
│   │   ├── keymaps.lua      # Key bindings (buffer nav, window splits, formatting)
│   │   ├── autocmds.lua     # Autocommand definitions
│   │   ├── globals.lua      # Global variables
│   │   └── diagnostics.lua  # Diagnostic configuration
│   ├── plugins/             # Individual plugin configurations (lazy-loaded specs)
│   │   ├── conform.lua      # Code formatter with per-language settings
│   │   ├── nvim-lint.lua    # Linter configuration
│   │   ├── nvim-lspconfig.lua  # LSP client setup
│   │   ├── blink-cmp.lua    # Completion engine
│   │   ├── nvim-treesitter.lua # Syntax highlighting and parsing
│   │   ├── lualine.lua      # Status line
│   │   ├── gitsigns.lua     # Git signs integration
│   │   ├── which-key.lua    # Key binding help
│   │   ├── nvim-dap.lua     # Debugging adapter protocol
│   │   ├── snacks.lua       # UI utilities
│   │   └── [other plugins]
│   ├── servers/             # Language Server Protocol (LSP) server configurations
│   │   ├── init.lua         # LSP bootstrap and capability setup
│   │   ├── lua_ls.lua       # Lua language server
│   │   ├── pyright.lua      # Python language server
│   │   ├── ts_ls.lua        # TypeScript language server
│   │   ├── clangd.lua       # C/C++ language server
│   │   ├── rust_analyzer.lua # Rust language server
│   │   ├── bashls.lua       # Bash language server
│   │   └── [other servers]
│   └── utils/               # Utility modules
│       ├── lsp.lua          # LSP helpers
│       └── diagnostics.lua  # Diagnostic helpers
└── .stylua.toml             # Stylua formatter config (Lua formatting)
```

### Plugin Manager: lazy.nvim

- **Bootstrap**: Automatically clones lazy.nvim to `~/.local/share/nvim/lazy/lazy.nvim` if not present
- **Plugin specs**: Defined in `lua/plugins/` directory, auto-imported by lazy.nvim
- **Color scheme**: Uses `tokyonight-night` as default during plugin installation
- **Update checking**: Enabled by default to check for plugin updates

### LSP Architecture

LSP is managed through two layers:

1. **`lua/servers/init.lua`**: Central orchestration
   - Sets up default LSP capabilities
   - Merges with blink.cmp capabilities for completion
   - Requires and initializes each language server module
   - Enables servers via `vim.lsp.enable()`

2. **`lua/servers/*.lua`**: Individual server configurations
   - Each server (lua_ls, pyright, ts_ls, etc.) is a separate module
   - Configured with language-specific settings and attach callbacks

### Formatter & Linter Configuration

**Conform.nvim** (formatting):
- Configured in `lua/plugins/conform.lua`
- Format on save enabled (500ms timeout, fallback to LSP)
- Per-language formatters:
  - Lua: stylua
  - Python: ruff_format
  - JavaScript/TypeScript: prettierd
  - C/C++: clang-format
  - Bash: shfmt
  - Web (HTML/CSS/JSON/YAML/Markdown): prettierd

**nvim-lint** (linting):
- Configured in `lua/plugins/nvim-lint.lua`
- Lints on file save
- Per-language linters:
  - JavaScript/TypeScript: eslint_d
  - Lua: luacheck
  - C/C++: cpplint
  - Rust: clippy
  - Python: ruff

### Key Configuration Files

- **`.stylua.toml`**: Lua formatter settings (160 char width, single quotes, Unix line endings)
- **`.luarc.json`**: Lua language server diagnostics (disables missing-parameter checks)
- **`lua/config/options.lua`**: Comprehensive NeoVim editor settings (95 lines)
- **`lua/config/keymaps.lua`**: Custom key bindings for productivity

## Common Commands

### Working with Configuration

| Task | Command |
|------|---------|
| Edit NeoVim config | `nvim ~/.config/nvim/init.lua` (also mapped to `<leader>rc` in NeoVim) |
| Format Lua files | `stylua lua/` or in NeoVim: `<leader>cf` |
| Check Lua code | `luacheck lua/` |

### Formatting & Linting

All formatting happens on save automatically. Manual formatting:
- In NeoVim: `:ConformInfo` to check formatters, `<leader>cf` to format manually

### Plugin Management

| Task | Command |
|------|---------|
| View installed plugins | `:Lazy` in NeoVim |
| Update all plugins | `:Lazy update` |
| Check for plugin issues | `:Lazy check` |
| View plugin changelog | `:Lazy log <plugin-name>` |

### LSP Operations

| Keybinding | Action |
|-----------|--------|
| `gd` | Go to definition |
| `gr` | Go to references |
| `<leader>D` | Go to type definition |
| `gi` | Go to implementation |
| `<leader>ca` | Code actions |
| `<leader>rn` | Rename symbol |

## Development Practices

### Adding a New LSP Server

1. Create a new file `lua/servers/my_server.lua` following the pattern of existing servers
2. Export a function that accepts `capabilities` and sets up the server with `vim.lsp.start()`
3. Import and initialize the server in `lua/servers/init.lua`
4. Add the server name to the `vim.lsp.enable()` table

### Adding a New Plugin

1. Create a `lua/plugins/my_plugin.lua` file with a lazy.nvim spec
2. Return a table with `plugin_url` and configuration
3. Use `event`, `cmd`, or `keys` for lazy loading conditions
4. Plugin is automatically loaded by lazy.nvim from the plugins directory

### Formatting Rules

- Use StyLua for Lua files (configured with 160 char width, single quotes)
- Format on save is enabled; manually trigger with `<leader>cf`
- Web files (HTML/CSS/JSON/YAML/Markdown) use Prettier via prettierd

## Important Notes

- NeoVim configuration is written entirely in Lua (no VimScript)
- lazy.nvim is self-bootstrapping - no manual installation needed
- LSP capabilities are centrally managed in `lua/servers/init.lua`
- All Lua code should conform to stylua rules defined in `.stylua.toml`
- Keymaps include quality-of-life improvements (centered navigation, better window management)
- Persistent undo is enabled and stored in `~/.local/share/nvim/undodir`
