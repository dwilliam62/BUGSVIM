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
function Add-ToPath($NewPath, $Scope = 'User') {
    if (-not (Test-Path $NewPath)) { return }
    $current = [Environment]::GetEnvironmentVariable('Path', $Scope)
    if ([string]::IsNullOrEmpty($current)) { $current = '' }
    $parts = $current.Split(';') | Where-Object { $_ -ne '' }
    if ($parts -notcontains $NewPath) {
        $updated = ($parts + $NewPath) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $updated, $Scope)
    }
    if ($env:Path.Split(';') -notcontains $NewPath) {
        $env:Path = $env:Path + ';' + $NewPath
    }
}

Write-Info '==============================================================='
Write-Info '  bugsvim - Windows Installation (PowerShell)'
Write-Info '==============================================================='
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
    try {
        Stop-Process -Name nvim -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warn 'WARN: Failed to stop running nvim processes'
    }
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
            Write-Ok "OK: Backup created: $backupDir"
        } else {
            Write-Warn 'Skipping backup'
        }
    }

    if (-not $SkipRemove) {
        Write-Info 'Removing existing NeoVim config and data...'
        if (Test-Path $configDir) {
            try {
                Remove-Item -Path $configDir -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warn "WARN: Failed to remove $configDir (files may be in use)"
            }
        }
        if (Test-Path $dataDir) {
            try {
                Remove-Item -Path $dataDir -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warn "WARN: Failed to remove $dataDir (files may be in use)"
            }
        }
        Write-Ok 'OK: Cleanup attempted'
    } else {
        Write-Warn 'Skipping removal of existing config/data'
    }
} else {
    Write-Ok 'OK: No existing NeoVim configuration found'
}

Write-Info 'Copying bugsvim config to LocalAppData...'
New-Item -ItemType Directory -Path $configDir -Force | Out-Null
Copy-Item -Path $sourceConfig\* -Destination $configDir -Recurse -Force
Write-Ok "OK: bugsvim config copied to $configDir"

if ($InstallDeps) {
    Write-Info 'Installing dependencies (winget/npm/pip)...'
    if (-not (Test-Command 'gcc') -or -not (Test-Command 'make')) {
        Write-Info 'Installing build tools (gcc/make) via MSYS2...'
        if (-not (Test-Path 'C:\msys64\usr\bin\bash.exe')) {
            if (Test-Command 'winget') {
                try {
                    winget install --id MSYS2.MSYS2 -e --source winget --accept-source-agreements --accept-package-agreements | Out-Null
                    Write-Ok 'OK: Installed MSYS2'
                } catch {
                    Write-Warn 'WARN: Failed to install MSYS2'
                }
            } else {
                Write-Warn 'WARN: winget not found; cannot install MSYS2'
            }
        }

        if (Test-Path 'C:\msys64\usr\bin\bash.exe') {
            try {
                C:\msys64\usr\bin\bash.exe -lc "pacman -Syu --noconfirm"
            } catch {
                Write-Warn 'WARN: MSYS2 update may have required a restart; continuing'
            }
            try {
                C:\msys64\usr\bin\bash.exe -lc "pacman -S --needed --noconfirm base-devel mingw-w64-x86_64-toolchain"
                Write-Ok 'OK: Installed MSYS2 build toolchain'
            } catch {
                Write-Warn 'WARN: Failed to install MSYS2 build toolchain'
            }
            Add-ToPath 'C:\msys64\mingw64\bin'
            Add-ToPath 'C:\msys64\usr\bin'
        }
    }

    if (-not (Test-Command 'zig')) {
        Write-Info 'Installing Zig via winget...'
        if (Test-Command 'winget') {
            try {
                winget install --id zig.zig -e --source winget --accept-source-agreements --accept-package-agreements --scope machine | Out-Null
                Write-Ok 'OK: Installed Zig'
            } catch {
                Write-Warn 'WARN: Failed to install Zig (try running as Administrator)'
            }
        } else {
            Write-Warn 'WARN: winget not found; cannot install Zig'
        }
    }
    if (Test-Path 'C:\Program Files\LLVM\bin') {
        Add-ToPath 'C:\Program Files\LLVM\bin'
    }
    if (-not (Test-Command 'zig')) {
        $zigLocations = @(
            'C:\Program Files\Zig',
            'C:\Program Files (x86)\Zig'
        )
        foreach ($loc in $zigLocations) {
            if (Test-Path (Join-Path $loc 'zig.exe')) {
                Add-ToPath $loc
            }
        }
        $wingetZig = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\zig.zig*" -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'zig.exe' } |
            Where-Object { Test-Path $_ } |
            Select-Object -First 1
        if ($wingetZig) {
            Add-ToPath (Split-Path -Parent $wingetZig)
        }
    }

    if (Test-Command 'winget') {
        $wingetPkgs = @(
            'Neovim.Neovim',
            'Git.Git',
            'BurntSushi.ripgrep.MSVC',
            'sharkdp.fd',
            'jqlang.jq',
            'OpenJS.NodeJS.LTS',
            'Python.Python.3.12',
            'LLVM.LLVM',
            'LuaLS.lua-language-server'
        )

        foreach ($pkg in $wingetPkgs) {
            Write-Info "Installing $pkg via winget..."
            try {
                winget install --id $pkg -e --source winget --accept-source-agreements --accept-package-agreements | Out-Null
                Write-Ok "OK: Installed $pkg"
            } catch {
                Write-Warn "WARN: Failed to install $pkg"
            }
        }

        if (-not (Test-Command 'fd')) {
            $fdExe = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter fd.exe -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if ($fdExe) {
                Add-ToPath (Split-Path -Parent $fdExe)
                if (Test-Command 'fd') {
                    Write-Ok 'OK: fd is now on PATH'
                }
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
            '@johnnymorganz/stylua-bin',
            'prettier'
        )
        foreach ($pkg in $npmPkgs) {
            Write-Info "Installing $pkg via npm..."
            try {
                npm install -g $pkg | Out-Null
                Write-Ok "OK: Installed $pkg"
            } catch {
                Write-Warn "WARN: Failed to install $pkg"
            }
        }
    } else {
        Write-Warn 'npm not found; skipping npm packages'
    }

    Write-Info 'Installing ruff and pyright via pip...'
    $pipInstalled = $false
    if (Test-Command 'python') {
        try {
            python -m pip install --user ruff pyright | Out-Null
            $pipInstalled = $true
        } catch {
            $pipInstalled = $false
        }
    } elseif (Test-Command 'py') {
        try {
            py -m pip install --user ruff pyright | Out-Null
            $pipInstalled = $true
        } catch {
            $pipInstalled = $false
        }
    } else {
        Write-Warn 'WARN: python not found; skipping pip packages'
    }
    if ($pipInstalled) {
        Write-Ok 'OK: Installed ruff and pyright'
    } else {
        Write-Warn 'WARN: Failed to install ruff/pyright'
    }
}

if (-not $SkipVerify) {
    Write-Host ''
    Write-Info 'Verifying installation...'

    if (Test-Command 'nvim') {
        $verLine = & nvim --version | Select-Object -First 1
        Write-Ok "OK: $verLine"
    } else {
        Write-Warn 'WARN: nvim not found in PATH'
    }

    $commands = @(
        'git', 'rg', 'fd', 'node', 'npm', 'python',
        'clangd', 'lua-language-server', 'pyright', 'ruff',
        'stylua', 'shfmt', 'clang-format', 'prettier', 'prettierd',
        'gcc', 'make', 'zig'
    )
    foreach ($cmd in $commands) {
        if (Test-Command $cmd) {
            Write-Ok "OK: $cmd"
        } else {
            Write-Warn "WARN: $cmd (missing)"
        }
    }
}

Write-Host ''
Write-Info 'Next steps:'
Write-Host '  1. Launch Neovim: nvim'
Write-Host '  2. Plugins will auto-install on first launch'
Write-Host '  3. Verify health: :checkhealth'
Write-Host ''
