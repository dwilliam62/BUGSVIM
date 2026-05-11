# Nevide starts in a huge font size (noticed on debian)

## Fix

- In `~/.config/nvim/init.lua` add:

```vim
if vim.g.neovide then
    -- Font settings
    vim.o.guifont = "CaskaydiaCove Nerd Font:h11"

    -- Global scale (The "Huge" fix)
    vim.g.neovide_scale_factor = 0.9

    -- Optional: Smoothing and Blur (Xeon/GPU can handle this easily)
    vim.g.neovide_cursor_animation_length = 0.13
    vim.g.neovide_cursor_trail_size = 0.8
end
```
