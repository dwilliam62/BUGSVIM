param(
    [switch]$InstallDeps,
    [switch]$Force,
    [switch]$NoBackup,
    [switch]$SkipRemove,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

function Write-Info($Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn($Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err($Message) { Write-Host $Message -ForegroundColor Red }

function Test-Command($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Confirm-Action($Prompt) {
    if ($Force) { return $true }
    $reply = Read-Host $Prompt
    return $reply -match '^[Yy]'
}

Write-Info '╔════════════════════════════════════════════════════════════════╗'
Write-Info '║   bugsvim - Windows Installation (PowerShell)                  ║'
Write-Info '╚════════════════════════════════════════════════════════════════╝'
Write-Host ''

if (-not $IsWindows) {
    Write-Warn 'This script is intended for Windows.'
    if (-not (Confirm-Action 'Continue anyway? (y/n)')) {
        exit 1
    }
}

$scriptDir = Split-Path -Parent $PSCommandPath
$sourceConfig = Join-Path $scriptDir 'nvim'
if (-not (Test-Path $sourceConfig)) {
    Write-Err "Could not find 'nvim' directory next to the script: $sourceConfig"
    exit 1
}

$configDir = Join-Path $env:LOCALAPPDATA 'nvim'
$dataDir = Join-Path $env:LOCALAPPDATA 'nvim-data'

Write-Info 'Checking existing NeoVim configuration...'
$hasConfig = (Test-Path $configDir) -or (Test-Path $dataDir)

if ($hasConfig) {
    if (-not $NoBackup) {
        if (Confirm-Action 'Backup existing config? (y/n)') {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backupDir = Join-Path $HOME "neovim-backup-$timestamp"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

            if (Test-Path $configDir) {
                Copy-Item -Path $configDir -Destination (Join-Path $backupDir 'nvim') -Recurse -Force
            }
            if (Test-Path $dataDir) {
                Copy-Item -Path $dataDir -Destination (Join-Path $backupDir 'nvim-data') -Recurse -Force
            }
            Write-Ok "✓ Backup created: $backupDir"
        } else {
            Write-Warn 'Skipping backup'
        }
    }

    if (-not $SkipRemove) {
        Write-Info 'Removing existing NeoVim config and data...'
        if (Test-Path $configDir) { Remove-Item -Path $configDir -Recurse -Force }
        if (Test-Path $dataDir) { Remove-Item -Path $dataDir -Recurse -Force }
        Write-Ok '✓ Existing config and data removed'
    } else {
        Write-Warn 'Skipping removal of existing config/data'
    }
} else {
    Write-Ok '✓ No existing NeoVim configuration found'
}

Write-Info 'Copying bugsvim config to LocalAppData...'
New-Item -ItemType Directory -Path $configDir -Force | Out-Null
Copy-Item -Path $sourceConfig\* -Destination $configDir -Recurse -Force
Write-Ok "✓ bugsvim config copied to $configDir"

if ($InstallDeps) {
    Write-Info 'Installing dependencies (winget/npm/pip)...'

    if (Test-Command 'winget') {
        $wingetPkgs = @(
            'Neovim.Neovim',
            'Git.Git',
            'BurntSushi.ripgrep.MSVC',
            'sharkdp.fd',
            'OpenJS.NodeJS.LTS',
            'Python.Python.3.12',
            'LLVM.LLVM'
        )

        foreach ($pkg in $wingetPkgs) {
            Write-Info "Installing $pkg via winget..."
            try {
                winget install --id $pkg -e --source winget --accept-source-agreements --accept-package-agreements | Out-Null
                Write-Ok "✓ Installed $pkg"
            } catch {
                Write-Warn "⚠ Failed to install $pkg"
            }
        }
    } else {
        Write-Warn 'winget not found; skipping system package installs'
    }

    if (Test-Command 'npm') {
        $npmPkgs = @(
            '@fsouza/prettierd',
            'vscode-langservers-extracted',
            'bash-language-server',
            'lua-language-server',
            '@johnnymorganz/stylua-bin',
            'prettier'
        )
        foreach ($pkg in $npmPkgs) {
            Write-Info "Installing $pkg via npm..."
            try {
                npm install -g $pkg | Out-Null
                Write-Ok "✓ Installed $pkg"
            } catch {
                Write-Warn "⚠ Failed to install $pkg"
            }
        }
    } else {
        Write-Warn 'npm not found; skipping npm packages'
    }

    if (Test-Command 'python') {
        Write-Info 'Installing ruff and pyright via pip...'
        try {
            python -m pip install --user ruff pyright | Out-Null
            Write-Ok '✓ Installed ruff and pyright'
        } catch {
            Write-Warn '⚠ Failed to install ruff/pyright'
        }
    } else {
        Write-Warn 'python not found; skipping pip packages'
    }
}

if (-not $SkipVerify) {
    Write-Host ''
    Write-Info 'Verifying installation...'

    if (Test-Command 'nvim') {
        $verLine = & nvim --version | Select-Object -First 1
        Write-Ok "✓ $verLine"
    } else {
        Write-Warn '⚠ nvim not found in PATH'
    }

    $commands = @(
        'git', 'rg', 'fd', 'node', 'npm', 'python',
        'clangd', 'lua-language-server', 'pyright', 'ruff',
        'stylua', 'shfmt', 'clang-format', 'prettier', 'prettierd'
    )
    foreach ($cmd in $commands) {
        if (Test-Command $cmd) {
            Write-Ok "✓ $cmd"
        } else {
            Write-Warn "⚠ $cmd (missing)"
        }
    }
}

Write-Host ''
Write-Info 'Next steps:'
Write-Host '  1. Launch Neovim: nvim'
Write-Host '  2. Plugins will auto-install on first launch'
Write-Host '  3. Verify health: :checkhealth'
Write-Host ''
