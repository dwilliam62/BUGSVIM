# Scripts de Instalación de bugsvim

Sistema de instalación automatizada para bugsvim compatible con Arch Linux, Debian/Ubuntu y derivadas (Linux Mint, Pop!_OS, Zorin OS), Fedora, openSUSE, Gentoo, Alpine, Bazzite, Windows, FreeBSD y OpenBSD.

## Instalador Raíz Unificado (Recomendado)

bugsvim proporciona un script instalador unificado `install.sh` que detecta automáticamente tu distribución o sistema operativo y ejecuta el controlador correspondiente:

```bash
# Instalación completa con autodetección
bash install.sh

# Ejecutar tareas de actualización (sincronizar config, verificar tree-sitter-cli, limpiar cachés)
bash install.sh -u

# Comprobar e instalar solo dependencias faltantes
bash install.sh -d

# Activar modo de depuración detallado
bash install.sh --debug

# Sobrescribir detección para distribuciones derivadas (ej. Zorin, Pop!_OS, Nobara)
bash install.sh --distro debian

# Listar todas las distribuciones soportadas
bash install.sh --list-distros
```

---

## Scripts Directos por Distribución

También puedes ejecutar directamente el script de tu distribución:

### Arch Linux y Derivadas (EndeavourOS, Manjaro, CachyOS, Garuda)
```bash
# Instalación limpia
bash install-arch.sh

# Actualizar instalación existente
bash install-arch.sh -u

# Comprobar e instalar dependencias faltantes
bash install-arch.sh -d
```

### Debian, Ubuntu y Derivadas (Linux Mint, Pop!_OS, Zorin OS, Elementary)
```bash
# Instalación limpia
bash install-debian.sh

# Actualizar instalación existente
bash install-debian.sh -u

# Comprobar e instalar dependencias faltantes
bash install-debian.sh -d
```

### Fedora y Derivadas (Nobara, RHEL, CentOS Stream, AlmaLinux, Rocky)
```bash
# Instalación limpia
bash install-fedora.sh

# Actualizar instalación existente
bash install-fedora.sh -u

# Comprobar e instalar dependencias faltantes
bash install-fedora.sh -d
```

### openSUSE (Tumbleweed / Leap)
```bash
# Instalación limpia
bash install-opensuse.sh

# Actualizar instalación existente
bash install-opensuse.sh -u

# Comprobar e instalar dependencias faltantes
bash install-opensuse.sh -d
```

### Gentoo Linux
```bash
# Instalación limpia
bash install-gentoo.sh

# Actualizar instalación existente
bash install-gentoo.sh -u

# Comprobar e instalar dependencias faltantes
bash install-gentoo.sh -d
```

### Alpine Linux
```bash
# Instalación limpia
bash install-alpine.sh

# Actualizar instalación existente
bash install-alpine.sh -u

# Comprobar e instalar dependencias faltantes
bash install-alpine.sh -d
```

### Bazzite (Fedora Atomic / Universal Blue)
```bash
# Instalación limpia
bash install-bazzite.sh

# Actualizar instalación existente
bash install-bazzite.sh -u

# Comprobar e instalar dependencias faltantes
bash install-bazzite.sh -d
```

### FreeBSD / OpenBSD
```bash
# FreeBSD
bash install-freebsd.sh
bash install-freebsd.sh -d

# OpenBSD
bash install-openbsd.sh
bash install-openbsd.sh -d
```

### Windows (PowerShell)
```powershell
.\install-windows.ps1
.\install-windows.ps1 -InstallDeps
```

---

## Opciones y Parámetros CLI

| Opción Corta | Opción Larga | Descripción |
|--------------|--------------|-------------|
| `-f` | `--force` | Fuerza la reinstalación/reconstrucción de paquetes |
| `-u` | `--update` | Ejecuta actualización: limpia caché de Treesitter, verifica `tree-sitter-cli`, sincroniza `nvim/` |
| `-d` | `--deps` | Modo dependencias: comprueba e instala paquetes faltantes sin modificar la config |
| `-D` | `--distro <nombre>` | Sobrescribe la autodetección del sistema (ej. `debian`, `arch`, `fedora`, `gentoo`) |
| | `--list-distros` | Muestra la lista de distribuciones reconocidas y sus alias |
| | `--debug` | Imprime mensajes de depuración detallados |
| `-h` | `--help` | Muestra el mensaje de ayuda y sintaxis |

## Qué Hacen los Scripts

Cada script ejecuta los siguientes pasos en orden:

1. **Copia de seguridad de la configuración existente** - Respalda la configuración previa de NeoVim si existe
   - Comprueba: `~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim`
   - Crea un respaldo con marca de tiempo: `~/neovim-backup-YYYYMMDD-HHMMSS/`
   - Pregunta al usuario antes de respaldar (opcional)
2. **Verificación de la distribución** - Comprueba que estás en el sistema operativo correcto
3. **Actualización del gestor de paquetes** - Actualiza los repositorios del sistema
4. **Instalación de dependencias básicas** - neovim, git, tree-sitter-cli, ripgrep, fd, herramientas de compilación, pkg-config
5. **Instalación de servidores de lenguaje (LSP)** - lua-language-server, python, nodejs, npm, clang, bash-language-server, rustup, nil
6. **Instalación de formateadores** - stylua, shfmt, clang-format, prettier
7. **Instalación de herramientas de conveniencia** - lazygit, bat, wl-clipboard (opcional)
8. **Instalación de paquetes globales de npm** - paquetes npm (@fsouza/prettierd, vscode-langservers-extracted)
9. **Instalación de paquetes Python** - paquetes pip (ruff, pyright)
10. **Opcional: Compilación de hyprls** - Opción interactiva para compilar Hyprland LSP desde el código fuente
11. **Verificación de la instalación** - Comprueba que todos los componentes estén instalados y accesibles en el PATH
12. **Copia de la configuración** - Copia los archivos de configuración a `~/.config/nvim`

**Modo de actualización (`-u` / `--update`):**
- Comprueba e instala `tree-sitter-cli` si no está presente.
- Elimina cachés obsoletas de `nvim-treesitter` (de versiones antiguas en la rama `master`).
- Sincroniza el directorio de configuración `nvim/` a `~/.config/nvim`.

## Notas Específicas por Distribución

### Arch Linux (`install-arch.sh`)

**Características:**
- Soporta asistentes de AUR tanto `yay` como `paru`.
- Instala automáticamente paquetes de AUR si se detecta un asistente:
  - hyprls
  - pyright
  - alejandra-bin
  - prettierd

---

### Debian/Ubuntu (`install-debian.sh`)

**Características:**
- Opción interactiva para compilar hyprls desde el código fuente.
- Instala paquetes desde los repositorios de Debian/Ubuntu + npm/pip para paquetes no disponibles en apt.

---

### Fedora (`install-fedora.sh`)

**Características:**
- Utiliza el gestor de paquetes `dnf`.
- Incluye el grupo `@development-tools`.
- Inicializa la cadena de herramientas de Rust automáticamente.

---

### Gentoo Linux (`install-gentoo.sh`)

**Características:**
- Compatible con NeoVim 0.10, 0.11 y 0.12+.
- Utiliza Portage (`emerge`) y opcionalmente overlays como GURU.

---

## Función de Copia de Seguridad

Cada script comprueba automáticamente si ya existe una configuración de NeoVim y ofrece crear una copia de seguridad antes de instalar.

### Qué se respalda

- `~/.config/nvim` - Archivos de configuración
- `~/.local/share/nvim` - Datos de plugins y archivos en tiempo de ejecución
- `~/.local/state/nvim` - Estado de sesión e historial

### Ubicación del respaldo

```
~/neovim-backup-YYYYMMDD-HHMMSS/
├── .config-nvim/          # Desde ~/.config/nvim
├── .local-share-nvim/     # Desde ~/.local/share/nvim
└── .local-state-nvim/     # Desde ~/.local/state/nvim
```

### Restaurar una copia de seguridad

```bash
# Listar respaldos
ls ~/ | grep neovim-backup

# Restaurar un respaldo específico
cp -r ~/neovim-backup-20251218-005700/.config-nvim ~/.config/nvim
cp -r ~/neovim-backup-20251218-005700/.local-share-nvim ~/.local/share/nvim
cp -r ~/neovim-backup-20251218-005700/.local-state-nvim ~/.local/state/nvim
```

## Verificación Posterior a la Instalación

```bash
# Comprobar servidores LSP específicos
which lua-language-server
which clangd
which pyright

# Comprobar formateadores y CLI de treesitter
which stylua
which shfmt
which tree-sitter

# Iniciar NeoVim y verificar el estado
nvim
:LspInfo
:checkhealth
```
