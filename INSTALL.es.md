# Guía de Instalación de bugsvim

Configuración rápida para bugsvim en Debian/Ubuntu, Arch Linux, Fedora, Gentoo, OpenSUSE, Alpine, Bazzite, Windows, FreeBSD y OpenBSD.

## Instalación Automatizada (Recomendada)

Ejecuta el instalador unificado para detectar tu distribución automáticamente:

```bash
bash install.sh
```

Otras opciones disponibles:
```bash
# Comprobar e instalar únicamente dependencias faltantes
bash install.sh -d

# Actualizar instalación existente
bash install.sh -u

# Forzar una distribución específica (ej. Zorin, Pop!_OS, Linux Mint)
bash install.sh --distro debian

# Listar distribuciones compatibles
bash install.sh --list-distros
```

O ejecuta directamente el script de tu distribución:

### Windows (PowerShell)
```powershell
# Instalación limpia (copia configuración)
.\install-windows.ps1

# Instalación completa con dependencias (winget, build tools, LSPs, formateadores)
.\install-windows.ps1 -InstallDeps

# Actualizar instalación existente (sincronizar config, limpiar caché antigua de TS, asegurar tree-sitter CLI)
.\install-windows.ps1 -Update

# Comprobar e instalar únicamente dependencias faltantes
.\install-windows.ps1 -Deps
```

Estos scripts se encargarán de:
- Detectar tu distribución
- Instalar todos los paquetes y servidores de lenguaje requeridos
- Instalar paquetes de npm y pip
- Verificar la instalación
- Mostrar los siguientes pasos

---

## Instalación Manual

### Debian / Ubuntu

#### En una sola línea (Base + Formateadores)
```bash
sudo apt-get update && sudo apt-get install -y \
  neovim git tree-sitter-cli ripgrep fd-find curl build-essential pkg-config \
  lua-language-server python3-pip nodejs npm clang clang-tools \
  bash-language-server rustup nil stylua shfmt clang-format prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted && \
pip3 install --user ruff pyright
```

---

### Arch Linux

#### En una sola línea (Base + Formateadores)
```bash
sudo pacman -S --noconfirm \
  neovim git tree-sitter-cli ripgrep fd curl base-devel pkg-config \
  lua-language-server python nodejs npm clang \
  bash-language-server rustup nil stylua shfmt clang prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted
```

---

### Fedora

#### En una sola línea (Base + Formateadores)
```bash
sudo dnf update -y && sudo dnf install -y \
  neovim git tree-sitter-cli ripgrep fd curl @development-tools pkg-config \
  lua lua-language-server python3-devel python3-pip nodejs npm clang \
  clang-tools-extra bash-language-server rust nil stylua shfmt prettier && \
npm install -g @fsouza/prettierd vscode-langservers-extracted && \
pip3 install --user ruff pyright
```

---

## Qué se Instala

| Componente | Propósito |
|------------|-----------|
| **neovim** | Editor de texto (0.10, 0.11, 0.12+) |
| **git** | Control de versiones |
| **tree-sitter-cli** | Compilador de analizadores sintácticos Treesitter |
| **ripgrep, fd** | Búsqueda y navegación rápida de archivos |
| **lua-language-server** | LSP para Lua |
| **python3, pip3** | Entorno Python y pyright |
| **nodejs, npm** | Entorno Node y paquetes de npm |
| **clang, clang-tools** | Compilador C/C++ y clangd |
| **bash-language-server** | LSP para Bash |
| **rustup / rust** | Cadena de herramientas de Rust |
| **nil** | LSP para Nix |
| **stylua** | Formateador para Lua |
| **shfmt** | Formateador para Bash |
| **clang-format** | Formateador para C/C++ |
| **prettier** | Formateador Web |
| **@fsouza/prettierd** | Demonio de Prettier (mayor velocidad) |
| **vscode-langservers-extracted** | LSP para HTML y CSS |

---

## Verificación

Tras la instalación, verifica que todo funcione correctamente:

```bash
# Comprobar servidores LSP
lua-language-server --version
clangd --version
pyright --version

# Comprobar compilador tree-sitter
tree-sitter --version

# Comprobar paquetes npm
npm list -g @fsouza/prettierd

# Iniciar neovim y comprobar salud
nvim --headless -c 'checkhealth' -c 'qa'
```

---

## Siguientes Pasos

1. Clonar la configuración de bugsvim: `git clone https://github.com/ddubs/bugsvim ~/.config/nvim`
2. Iniciar neovim: `nvim`
3. Los plugins se instalarán automáticamente en el primer inicio (lazy.nvim)
4. Ejecutar `:checkhealth` para verificar los servidores LSP
