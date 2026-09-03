# bugsvim — Configuración Moderna de NeoVim

<img src="/assets/preview.png" width="100%" />
<img src="/assets/preview2.png" width="100%" />
<img src="/assets/preview3.png" width="100%" />
<img src="/assets/preview4.png" width="100%" />

## Acerca de

bugsvim es una configuración de NeoVim cuidadosamente diseñada para flujos de trabajo de desarrollo modernos. Combina la potencia de la configuración basada en Lua con una selección optimizada de plugins para proporcionar una experiencia de edición rápida, extensible y agradable.

### Agradecimientos

Esta configuración es una bifurcación (fork) de **[BUGSVIM](https://github.com/Abhra00/BUGSVIM)** creado por [Abhra00](https://github.com/Abhra00). Agradecemos enormemente su excelente base y extendemos nuestro agradecimiento a:

- **Abhra00** por el proyecto original BUGSVIM
- **folke** y el equipo de **lazy.nvim** por el excepcional gestor de plugins
- Los colaboradores de **nvim-treesitter** por el análisis sintáctico inteligente
- Todos los mantenedores de los plugins integrados en esta configuración

## Características

### 🎨 Visualmente Atractivo y Fluido

- Tema **Tokyo Night** con valores predeterminados cuidadosamente ajustados
- Barra de estado dinámica con **lualine** que muestra información del editor en tiempo real
- Persistencia inteligente de sesión que sobrevive a los reinicios
- Animaciones fluidas y retroalimentación visual

### 🧠 Desarrollo Inteligente

- **Ecosistema LSP completo** con soporte para:
  - Lua (lua-language-server)
  - Python (Pyright + Ruff)
  - TypeScript / JavaScript (ts_ls)
  - C / C++ (clangd)
  - Rust (rust-analyzer)
  - Bash (bash-language-server)
  - HTML, CSS, Tailwind CSS
  - Hyprland (hyprls)
  - Java (JDTLS)
- **Diagnósticos mejorados** con mensajes de error en línea, signos en el gutter y ventanas flotantes
- **Autocompletado avanzado** mediante Blink Cmp con caché inteligente
- **Soporte multiformateador** mediante Conform (stylua, shfmt, clang-format, prettier)
- **Linting en tiempo real** con nvim-lint
- **Depuración interactiva (DAP)** mediante nvim-dap

### 🚀 Productividad

- Resaltado de sintaxis y textobjects impulsados por **Treesitter (rama main)**
- **Búsqueda difusa rápida (fuzzy finding)** y navegación
- **Integración con Git** mediante gitsigns para inline blame y diffs de hunks
- **Seguimiento de tareas y TODOs** con todo-comments
- **Snippets inteligentes** para codificación rápida
- **Lazy loading** para tiempos de inicio ultrarrápidos
- Integración con **Which-key** para descubrir atajos de teclado
- **Interfaz mejorada con Noice.nvim** - línea de comandos y notificaciones en ventanas flotantes

### 🛠️ Herramientas de Desarrollo

- Soporte para desarrollo en **Spring Boot**
- Desarrollo en **Java** mediante JDTLS
- **Soporte Markdown** con vista previa en vivo en el navegador (markdown-preview.nvim)
- **Edición mejorada de Markdown** con soporte para casillas de verificación y tablas (markdown.nvim)
- **Snacks.nvim** para notificaciones, animaciones y mejoras de calidad de vida
- Utilidades **Mini.nvim** para edición mejorada
- **LazyDev** para documentación integrada de la API de Neovim

### ✨ Detalles Adicionales

- Historial de deshacer persistente (persistent undo)
- Autoformateo al guardar
- Atajos de teclado inteligentes
- Manejo elegante de errores

## Instalación

### Instalación Rápida (Recomendada)

bugsvim proporciona scripts de instalación y actualización automatizados para las principales distribuciones:

#### Arch Linux

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-arch.sh

# O actualizar instalación existente
bash install-arch.sh -u
```

#### Debian / Ubuntu

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-debian.sh

# O actualizar instalación existente
bash install-debian.sh -u
```

#### Fedora

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-fedora.sh

# O actualizar instalación existente
bash install-fedora.sh -u
```

#### Gentoo Linux

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-gentoo.sh

# O actualizar instalación existente
bash install-gentoo.sh -u
```

#### OpenSUSE

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-opensuse.sh

# O actualizar instalación existente
bash install-opensuse.sh -u
```

#### Alpine Linux

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-alpine.sh

# O actualizar instalación existente
bash install-alpine.sh -u
```

#### Bazzite (Fedora Atomic)

```bash
git clone https://github.com/dwilliam62/bugsvim ~/.config/bugsvim
cd ~/.config/bugsvim
bash install-bazzite.sh

# O actualizar instalación existente
bash install-bazzite.sh -u
```

#### FreeBSD / OpenBSD

```bash
# FreeBSD
bash install-freebsd.sh

# OpenBSD
bash install-openbsd.sh
```

#### Windows (PowerShell)

```powershell
git clone https://github.com/dwilliam62/bugsvim $env:LOCALAPPDATA\bugsvim
Set-Location $env:LOCALAPPDATA\bugsvim
.\install-windows.ps1
```

**Los scripts de instalación ofrecen:**

- **Instalación Completa**: Detecta tu distribución, respalda configuraciones existentes de NeoVim, instala paquetes del sistema y LSPs requeridos, configura npm a nivel de usuario, verifica la instalación y copia la configuración a `~/.config/nvim`.
- **Modo de Actualización Modular (`-u` / `--update`)**: Comprueba e instala `tree-sitter-cli`, elimina cachés antiguas de `nvim-treesitter` y sincroniza la configuración más reciente.

Consulta [INSTALL.es.md](./INSTALL.es.md) e [INSTALL-SCRIPTS.es.md](./INSTALL-SCRIPTS.es.md) para más detalles.

## Paquetes Requeridos

### Dependencias Principales

| Paquete                                      | Propósito                         |
| -------------------------------------------- | --------------------------------- |
| **neovim** (0.10+)                           | Editor de texto (0.10, 0.11, 0.12+) |
| **git**                                      | Control de versiones              |
| **tree-sitter-cli**                          | Compilador de analizadores sintácticos Treesitter |
| **ripgrep**                                  | Búsqueda rápida de archivos       |
| **fd**                                       | Recorrido rápido de directorios   |
| **curl**                                     | Solicitudes de red                |
| **build-essential** / **@development-tools** | Compilación C/C++                 |
| **pkg-config**                               | Bibliotecas de desarrollo         |

### Servidores de Lenguaje (LSP)

| LSP                      | Lenguaje(s)           | Instalación       |
| ------------------------ | --------------------- | ----------------- |
| **lua-language-server**  | Lua                   | Paquete del sistema |
| **clangd**               | C/C++                 | Paquete del sistema |
| **pyright**              | Python                | pip3 o AUR        |
| **ts_ls**                | TypeScript/JavaScript | Npm               |
| **rust-analyzer**        | Rust                  | Paquete del sistema |
| **bash-language-server** | Bash/Shell            | Npm               |
| **html**                 | HTML                  | Npm               |
| **cssls**                | CSS                   | Npm               |
| **tailwindcss**          | Tailwind CSS          | Npm               |
| **hyprls**               | Config de Hyprland    | AUR / Compilación manual |
| **JDTLS**                | Java                  | Npm               |

### Formateadores de Código

| Formateador      | Lenguaje(s)       | Instalación      |
| ---------------- | ----------------- | ---------------- |
| **stylua**       | Lua               | Paquete del sistema |
| **shfmt**        | Shell/Bash        | Paquete del sistema |
| **clang-format** | C/C++             | Paquete del sistema |
| **prettier**     | Web (JS/CSS/HTML) | Npm              |
| **prettierd**    | Web (modo demonio)| Npm              |

### Herramientas Opcionales

| Herramienta      | Propósito                  | Instalación      |
| ---------------- | -------------------------- | ---------------- |
| **lazygit**      | Cliente de interfaz Git    | Paquete del sistema |
| **bat**          | Visualizador con resaltado | Paquete del sistema |
| **wl-clipboard** | Portapapeles (Wayland)     | Paquete del sistema |

## Primer Inicio

Tras la instalación:

```bash
# Recarga tu shell para aplicar los cambios del PATH
source ~/.$(basename $SHELL)rc

# Inicia NeoVim
nvim

# Los plugins se instalarán automáticamente en el primer inicio
# Verifica el estado del LSP: :LspInfo
# Comprueba la salud general: :checkhealth
```

Para una guía detallada tras la instalación, consulta [POST-INSTALL.es.md](./POST-INSTALL.es.md).

## Estructura de la Configuración

Toda la configuración está organizada en `~/.config/nvim/lua/`:

```
nvim/
├── init.lua              # Punto de entrada
└── lua/
    ├── config/           # Configuración principal
    │   ├── options.lua   # Opciones y ajustes del editor
    │   ├── keymaps.lua   # Atajos de teclado
    │   ├── lazy.lua      # Configuración del gestor de plugins
    │   ├── autocmds.lua  # Comandos automáticos
    │   └── globals.lua   # Variables globales
    ├── plugins/          # Especificaciones de plugins
    ├── servers/          # Configuraciones de LSP
    └── utils/            # Funciones de utilidad
```

## Solución de Problemas

Para problemas y soluciones comunes, consulta [POST-INSTALL.es.md](./POST-INSTALL.es.md).

## Licencia

Este proyecto está licenciado bajo la **Licencia Pública General GNU v3 (GPL-3.0)**.

Eres libre de:
- Usar este software para cualquier propósito
- Distribuir copias
- Modificar el código fuente

Bajo la condición de que:
- Proporciones la disponibilidad del código fuente
- Cualquier versión modificada también use GPL-3.0
- Incluyas la licencia y los avisos de derechos de autor

Consulta el archivo [LICENSE](./LICENSE) para ver el texto completo.
