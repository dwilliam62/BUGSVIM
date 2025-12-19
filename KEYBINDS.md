# bugsvim Keybindings

## Leader Key Shortcuts

The default leader key is `Space`. All keybinds use the `<leader>` prefix.

### Buffer Navigation

| Keybind | Description |
|---------|-------------|
| `<leader>bn` | Next buffer |
| `<leader>bp` | Previous buffer |

### Window Management

| Keybind | Description |
|---------|-------------|
| `<leader>sv` | Split window vertically |
| `<leader>sh` | Split window horizontally |
| `<C-h>` | Move to left window |
| `<C-j>` | Move to bottom window |
| `<C-k>` | Move to top window |
| `<C-l>` | Move to right window |

### Window Resizing

| Keybind | Description |
|---------|-------------|
| `<C-Up>` | Increase window height |
| `<C-Down>` | Decrease window height |
| `<C-Left>` | Decrease window width |
| `<C-Right>` | Increase window width |

### Configuration

| Keybind | Description |
|---------|-------------|
| `<leader>rc` | Edit NeoVim config (init.lua) |

### Markdown

| Keybind | Description |
|---------|-------------|
| `<leader>mc` | Toggle markdown checkbox |
| `<leader>mp` | Open markdown preview |
| `<leader>mt` | Toggle markdown preview on/off |
| `<leader>ms` | Stop markdown preview |

## Navigation Shortcuts

### Search Navigation

| Keybind | Description |
|---------|-------------|
| `n` | Next search result (centered) |
| `N` | Previous search result (centered) |

### Scrolling

| Keybind | Description |
|---------|-------------|
| `<C-d>` | Half page down (centered) |
| `<C-u>` | Half page up (centered) |

### Line Operations

| Keybind | Description |
|---------|-------------|
| `J` | Join lines and keep cursor position |

## Visual Mode

| Keybind | Description |
|---------|-------------|
| `<` | Indent left and reselect |
| `>` | Indent right and reselect |
| `p` | Paste without losing clipboard |

## Tips

- All leader keybinds start with `Space` followed by the letter
- Window navigation uses `Ctrl` + `hjkl` for Vim-like movement
- Search results are centered automatically for better visibility
- Markdown preview opens in your default browser with live updates
