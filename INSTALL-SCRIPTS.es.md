# Scripts de Instalación de bugsvim

Scripts de instalación automatizada para bugsvim en Arch Linux, Debian/Ubuntu, Fedora, Gentoo, OpenSUSE, Alpine, Bazzite, Windows, FreeBSD y OpenBSD.

## Inicio Rápido

Elige tu distribución y ejecuta el script correspondiente:

### Arch Linux

```bash
# Instalación limpia
bash install-arch.sh

# Actualizar instalación existente (sincronizar config, verificar tree-sitter-cli, limpiar cachés antiguas)
bash install-arch.sh -u
```

### Debian / Ubuntu

```bash
# Instalación limpia
bash install-debian.sh

# Actualizar instalación existente
bash install-debian.sh -u
```

### Fedora

```bash
# Instalación limpia
bash install-fedora.sh

# Actualizar instalación existente
bash install-fedora.sh -u
```

### Gentoo Linux

```bash
# Instalación limpia
bash install-gentoo.sh

# Actualizar instalación existente
bash install-gentoo.sh -u
```

### OpenSUSE

```bash
# Instalación limpia
bash install-opensuse.sh

# Actualizar instalación existente
bash install-opensuse.sh -u
```

### Alpine Linux

```bash
# Instalación limpia
bash install-alpine.sh

# Actualizar instalación existente
bash install-alpine.sh -u
```

### Bazzite (Fedora Atomic)

```bash
# Instalación limpia
bash install-bazzite.sh

# Actualizar instalación existente
bash install-bazzite.sh -u
```

### FreeBSD / OpenBSD

```bash
# FreeBSD
bash install-freebsd.sh

# OpenBSD
bash install-openbsd.sh
```

### Windows (PowerShell)

```powershell
.\install-windows.ps1
```

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
