# Atajos de Teclado de bugsvim

## Atajos con la Tecla Líder (Leader Key)

La tecla líder predeterminada es `Espacio` (`Space`). Todos los atajos utilizan el prefijo `<leader>`.

### Navegación de Búferes

| Atajo | Descripción |
|-------|-------------|
| `<leader>bn` | Siguiente búfer |
| `<leader>bp` | Búfer anterior |

### Gestión de Ventanas

| Atajo | Descripción |
|-------|-------------|
| `<leader>sv` | Dividir ventana verticalmente |
| `<leader>sh` | Dividir ventana horizontalmente |
| `<C-h>` | Mover a la ventana izquierda |
| `<C-j>` | Mover a la ventana inferior |
| `<C-k>` | Mover a la ventana superior |
| `<C-l>` | Mover a la ventana derecha |

### Redimensionamiento de Ventanas

| Atajo | Descripción |
|-------|-------------|
| `<C-Up>` | Aumentar altura de ventana |
| `<C-Down>` | Disminuir altura de ventana |
| `<C-Left>` | Disminuir anchura de ventana |
| `<C-Right>` | Aumentar anchura de ventana |

### Configuración

| Atajo | Descripción |
|-------|-------------|
| `<leader>rc` | Editar configuración de NeoVim (init.lua) |

### Markdown

| Atajo | Descripción |
|-------|-------------|
| `<leader>mc` | Alternar casilla de verificación (checkbox) |
| `<leader>mp` | Abrir vista previa de Markdown en el navegador |
| `<leader>mt` | Alternar vista previa de Markdown activada/desactivada |
| `<leader>ms` | Detener vista previa de Markdown |

## Atajos de Navegación

### Navegación de Búsqueda

| Atajo | Descripción |
|-------|-------------|
| `n` | Siguiente resultado de búsqueda (centrado en pantalla) |
| `N` | Resultado de búsqueda anterior (centrado en pantalla) |

### Desplazamiento (Scrolling)

| Atajo | Descripción |
|-------|-------------|
| `<C-d>` | Media página hacia abajo (centrado) |
| `<C-u>` | Media página hacia arriba (centrado) |

### Operaciones de Línea

| Atajo | Descripción |
|-------|-------------|
| `J` | Unir líneas manteniendo la posición del cursor |

## Modo Visual

| Atajo | Descripción |
|-------|-------------|
| `<` | Desplazar sangría a la izquierda y re-seleccionar |
| `>` | Desplazar sangría a la derecha y re-seleccionar |
| `p` | Pegar sin perder el contenido del portapapeles |

## Consejos

- Todos los atajos con tecla líder comienzan con `Espacio` seguido de la letra correspondiente.
- La navegación entre ventanas utiliza `Ctrl` + `hjkl` para mantener el movimiento clásico de Vim.
- Los resultados de búsqueda se centran automáticamente para mayor comodidad visual.
- La vista previa de Markdown se abre en tu navegador predeterminado con actualizaciones en tiempo real.
