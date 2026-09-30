# bugsvim Post-Installation Setup

After running the installation script, follow these steps to ensure everything works correctly.

## npm PATH Configuration

The installation scripts configure npm to use `~/.npm-global` for user-level global packages to avoid permission issues, and install user-level binaries into `~/.local/bin`. **Both** directories need to be in your PATH - `~/.local/bin` is where `ruff`, `pyright`, `lua-language-server`, `hyprls`, the `fd` link (Debian/Ubuntu) and `tectonic` live.

### Verify npm Configuration

```bash
npm config get prefix --location=per-user
# Should output: /home/your-username/.npm-global
```

### Add npm to Your Shell PATH

The npm packages installed in `~/.npm-global/bin` need to be in your PATH. Add the following to your shell configuration:

#### For Bash (`~/.bashrc`)
```bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
```

#### For Zsh (`~/.zshrc`)
```bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
```

#### For Fish (`~/.config/fish/config.fish`)
```fish
set -gx PATH $HOME/.npm-global/bin $HOME/.local/bin $PATH
```

### Apply Changes

After editing your shell configuration, reload it:

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc

# Fish
source ~/.config/fish/config.fish
```

Or simply open a new terminal window.

## Verify Language Servers are Available

After setup, verify the language servers are in your PATH:

```bash
# LSP servers
lua-language-server --version
clangd --version
pyright --version

# Formatters
stylua --version
prettier --version
shfmt --version
clang-format --version

# npm packages should now be accessible
which lua-language-server
which bash-language-server
which stylua
which prettier
```

## Troubleshooting

### Command not found: lua-language-server

**Problem:** npm packages installed but not in PATH

**Solution:**
1. Check npm prefix: `npm config get prefix --location=per-user`
2. Ensure `~/.npm-global/bin` is in your PATH
3. Add PATH export to your shell config file
4. Reload shell: `source ~/.bashrc` (or equivalent)

### Permission denied errors

**Problem:** npm tries to write to system directories

**Solution:**
1. Verify npm config: `npm config get prefix --location=per-user`
2. Should return: `/home/username/.npm-global`
3. If not, reset with: `npm config set prefix '~/.npm-global' --location=per-user`

### Packages missing in verification

If verification shows some packages missing:

**Debian/Ubuntu:**
```bash
# lua-language-server is not packaged for Debian/Ubuntu and has no npm package;
# the installer unpacks the upstream release into ~/.local
npm install -g bash-language-server @johnnymorganz/stylua-bin prettier @fsouza/prettierd
python3 -m pip install --user --break-system-packages pyright ruff
```

**Arch Linux:**
```bash
npm install -g bash-language-server
npm install -g @johnnymorganz/stylua-bin prettier @fsouza/prettierd
```

**Fedora/RHEL:**
```bash
npm install -g bash-language-server
npm install -g @johnnymorganz/stylua-bin prettier @fsouza/prettierd
```

## Clone bugsvim Configuration

Once language servers are verified working:

```bash
# Clone the bugsvim configuration
git clone https://github.com/ddubs/bugsvim ~/.config/nvim

# Launch NeoVim
nvim

# Plugins will auto-install on first launch (lazy.nvim)
```

## Verify NeoVim LSP

Inside NeoVim, check that LSP servers are connected:

```vim
:LspInfo
:checkhealth
```

### Expected `:checkhealth` results

Run it from a real terminal (not `--headless`, and with `TERM` set). The dependency
checks should all report OK. The following messages are expected and are not
installation problems:

- `Snacks.dashboard: setup did not run` - snacks skips the dashboard when there is
  no UI attached (headless, `nvim --headless`).
- `your terminal does not support the kitty graphics protocol` - only kitty,
  wezterm and ghostty support it; any other terminal reports this.
- `Terminal: command failed: { "infocmp", "-L" }` - `TERM` is unset (typical for
  headless runs); `infocmp` itself is installed.
- Warnings about missing treesitter languages - parsers are installed on demand,
  so they clear as files are opened.
- `markdown`/`latex`/`mermaid` rendering warnings - install `mmdc` and
  `tectonic`/`pdflatex` as shown above.

## Optional: Install Additional Packages

### Hyprland LSP (hyprls)

**Arch:**
```bash
yay -S hyprls
# or if using paru:
paru -S hyprls
```

**Debian/Ubuntu:**
Build from source:
```bash
git clone https://github.com/hyprwm/hyprland /tmp/hyprland
cd /tmp/hyprland
make hyprls
sudo cp hyprls /usr/local/bin/
```

**Fedora:**
Similar to Debian, build from source.

### Nix LSP (nil)

`nil` is not in the Arch repositories or the AUR, so build it from source:

```bash
git clone https://github.com/oxalica/nil /tmp/nil && cd /tmp/nil && cargo build --release
```

**Debian/Ubuntu/Fedora:**
Install via Nix:
```bash
nix run github:oxalica/nil
```

### Markdown preview tooling (mmdc, tectonic)

The installer adds the tools used by the in-editor markdown previews:

```bash
# Mermaid diagrams (installs a bundled browser, expect a few hundred MB)
npm install -g @mermaid-js/mermaid-cli

# LaTeX math - either a TeX distribution (pdflatex) or the static tectonic binary
# (the installer downloads it into ~/.local/bin)
```

Skip these with `INSTALL_DOC_TOOLS=n bash install.sh -d`.

### tree-sitter CLI version

`nvim-treesitter` (main branch) needs `tree-sitter-cli` >= 0.26.1 to compile parsers,
but several distributions package something older (Debian trixie ships 0.22.6). The
installer detects that and installs a newer build into `~/.local/bin` - downloading
the upstream release binary on Linux, or building it with cargo elsewhere.

## Frequently Asked Questions

### Q: Why use `~/.npm-global` instead of system npm?
A: Avoids permission issues and doesn't require `sudo` for global installs. Each user maintains their own npm packages.

### Q: Do I need to reinstall if I switch shells?
A: No, the npm configuration is persistent. Just add the PATH export to your new shell's config file.

### Q: Can I use system npm with sudo?
A: Not recommended. The installation scripts configure npm for user installs to prevent permission issues.

### Q: What if I already have npm packages installed globally?
A: The installation scripts use `--needed` flags and check for conflicts. Existing packages won't be reinstalled.

## Next Steps

1. ✓ Run installation script
2. ✓ Configure shell PATH for npm
3. ✓ Verify language servers are in PATH
4. ✓ Clone bugsvim configuration
5. ✓ Launch NeoVim and verify LSP
6. Start editing!

## Support

For issues with:
- **Language servers:** Check if executables are in PATH with `which <command>`
- **npm permissions:** Verify npm config with `npm config get prefix --location=per-user`
- **NeoVim LSP:** Run `:LspInfo` and `:checkhealth` inside NeoVim
- **Specific packages:** Refer to the troubleshooting section above
