# Neovide se inicia con un tamaño de fuente enorme (detectado en Debian)

## Solución

- En `~/.config/nvim/init.lua` agrega:

```lua
if vim.g.neovide then
    -- Configuración de fuente
    vim.o.guifont = "CaskaydiaCove Nerd Font:h11"

    -- Escala global (La solución para el tamaño "Enorme")
    vim.g.neovide_scale_factor = 0.9

    -- Opcional: Suavizado y desenfoque (Xeon/GPU pueden manejar esto fácilmente)
    vim.g.neovide_cursor_animation_length = 0.13
    vim.g.neovide_cursor_trail_size = 0.8
end
```
