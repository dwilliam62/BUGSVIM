# Configuración Posterior a la Instalación de bugsvim

Tras ejecutar el script de instalación, sigue estos pasos para asegurarte de que todo funcione correctamente.

## Configuración del PATH para npm

Los scripts de instalación configuran npm para utilizar `~/.npm-global` para los paquetes globales a nivel de usuario, evitando problemas de permisos con `sudo`.

### Verificar la Configuración de npm

```bash
npm config get prefix --location=per-user
# Debería mostrar: /home/tu-usuario/.npm-global
```

### Agregar npm al PATH de tu Shell

Los paquetes npm instalados en `~/.npm-global/bin` deben estar en tu variable PATH. Agrega lo siguiente a la configuración de tu shell:

#### Para Bash (`~/.bashrc`)
```bash
export PATH=~/.npm-global/bin:$PATH
```

#### Para Zsh (`~/.zshrc`)
```bash
export PATH=~/.npm-global/bin:$PATH
```

#### Para Fish (`~/.config/fish/config.fish`)
```fish
set -gx PATH ~/.npm-global/bin $PATH
```

### Aplicar los Cambios

Tras editar la configuración de tu shell, recárgala:

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc

# Fish
source ~/.config/fish/config.fish
```

O simplemente abre una nueva ventana de terminal.

## Verificar la Disponibilidad de Servidores de Lenguaje y Herramientas

Tras la configuración, comprueba que los servidores y binarios estén en tu PATH:

```bash
# Servidores LSP
lua-language-server --version
clangd --version
pyright --version

# Compilador Treesitter
tree-sitter --version

# Formateadores
stylua --version
prettier --version
shfmt --version
clang-format --version

# Los paquetes npm deben estar accesibles
which lua-language-server
which bash-language-server
which stylua
which prettier
```

## Solución de Problemas Comunes

### Comando no encontrado: lua-language-server

**Problema:** Los paquetes npm están instalados pero no se encuentran en el PATH.

**Solución:**
1. Comprueba el prefijo de npm: `npm config get prefix --location=per-user`
2. Asegúrate de que `~/.npm-global/bin` esté en tu PATH
3. Agrega la exportación al archivo de configuración de tu shell
4. Recarga tu shell: `source ~/.bashrc` (o equivalente)

### Errores de permisos denegados (Permission denied)

**Problema:** npm intenta escribir en directorios raíz del sistema.

**Solución:**
1. Verifica la configuración de npm: `npm config get prefix --location=per-user`
2. Debería devolver: `/home/tu-usuario/.npm-global`
3. Si no es así, establécelo con: `npm config set prefix '~/.npm-global' --location=per-user`

### Paquetes faltantes en la verificación

Si la verificación indica que faltan paquetes:

**Debian / Ubuntu:**
```bash
npm install -g lua-language-server bash-language-server
npm install -g @johnnymorganz/stylua-bin prettier @fsouza/prettierd
pip3 install --user ruff pyright
```

**Arch Linux:**
```bash
npm install -g bash-language-server
npm install -g @johnnymorganz/stylua-bin prettier @fsouza/prettierd
```

**Fedora:**
```bash
npm install -g bash-language-server
npm install -g @johnnymorganz/stylua-bin prettier @fsouza/prettierd
```

## Clonar la Configuración de bugsvim

Una vez verificadas las herramientas del sistema:

```bash
# Clonar el repositorio
git clone https://github.com/ddubs/bugsvim ~/.config/nvim

# Iniciar NeoVim
nvim

# Los plugins se instalarán automáticamente en el primer inicio (lazy.nvim)
```

## Verificar el LSP en NeoVim

Dentro de NeoVim, comprueba el estado de los servidores LSP y la salud general:

```vim
:LspInfo
:checkhealth
```

## Paquetes Opcionales Adicionales

### Hyprland LSP (hyprls)

**Arch Linux:**
```bash
yay -S hyprls
# o si utilizas paru:
paru -S hyprls
```

**Debian / Ubuntu / Fedora:**
Compilar desde el código fuente con Go:
```bash
GOBIN="$HOME/.local/bin" go install github.com/hyprland-community/hyprls/cmd/hyprls@latest
```

### Nix LSP (nil)

**Arch Linux (AUR):**
```bash
yay -S nil
```

**Debian / Ubuntu / Fedora:**
Instalar mediante Nix:
```bash
nix profile add nixpkgs#nil
```

## Preguntas Frecuentes

### P: ¿Por qué usar `~/.npm-global` en lugar de npm a nivel de sistema?
**R:** Evita conflictos de permisos y elimina la necesidad de `sudo` para instalaciones globales de npm. Cada usuario gestiona sus propios paquetes de manera aislada.

### P: ¿Debo reinstalar todo si cambio de shell?
**R:** No, la configuración de npm es persistente. Solo necesitas agregar la línea de exportación del PATH al archivo de configuración de tu nuevo shell.

### P: ¿Puedo usar npm del sistema con sudo?
**R:** No se recomienda. Los scripts configuran npm para instalaciones locales de usuario para prevenir problemas de permisos y sobreescrituras en el sistema.
