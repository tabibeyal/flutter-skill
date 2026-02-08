# Flutter Skill One-Click Installation Script (Windows PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "Flutter Skill One-Click Installation" -ForegroundColor Blue
Write-Host ""

# ========== Helper Functions ==========

function Install-ToolPriorityRules {
    $promptsDir = "$env:USERPROFILE\.claude\prompts"
    $targetFile = "$promptsDir\flutter-tool-priority.md"

    if (Test-Path $targetFile) {
        Write-Host "  [OK] Tool priority rules already installed" -ForegroundColor Green
        return
    }

    # Create directory
    if (-not (Test-Path $promptsDir)) {
        New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null
    }

    # Download from GitHub
    $url = "https://raw.githubusercontent.com/ai-dashboad/flutter-skill/main/docs/prompts/tool-priority.md"
    try {
        Invoke-WebRequest -Uri $url -OutFile $targetFile -UseBasicParsing
        Write-Host "  [OK] Tool priority rules installed" -ForegroundColor Green
        return
    } catch {
        # Fallback: try using the CLI
        try {
            & flutter-skill setup --silent 2>$null
            Write-Host "  [OK] Tool priority rules installed" -ForegroundColor Green
            return
        } catch {}
        try {
            & flutter-skill-mcp setup --silent 2>$null
            Write-Host "  [OK] Tool priority rules installed" -ForegroundColor Green
            return
        } catch {}
    }

    Write-Host "  [!] Could not install tool priority rules automatically" -ForegroundColor Yellow
    Write-Host "      Run manually: flutter-skill setup"
}

function Add-McpToJson {
    param([string]$FilePath, [string]$CmdName)

    $entry = @{ command = $CmdName; args = @("server") }

    if (Test-Path $FilePath) {
        try {
            $data = Get-Content $FilePath -Raw | ConvertFrom-Json
        } catch {
            $data = [PSCustomObject]@{}
        }
    } else {
        $parentDir = Split-Path $FilePath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        $data = [PSCustomObject]@{}
    }

    if (-not $data.mcpServers) {
        $data | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    $data.mcpServers | Add-Member -NotePropertyName "flutter-skill" -NotePropertyValue ([PSCustomObject]$entry) -Force

    $data | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding UTF8
}

function Show-IdeConfig {
    param([string]$CmdName)

    Write-Host ""
    Write-Host "Configuring IDE integration..." -ForegroundColor Blue

    # Claude Code
    $claudeDir = "$env:USERPROFILE\.claude"
    $claudeSettings = "$claudeDir\settings.json"
    if (Test-Path $claudeDir) {
        if ((Test-Path $claudeSettings) -and ((Get-Content $claudeSettings -Raw) -match "flutter-skill|flutter_skill")) {
            Write-Host "  [OK] Claude Code: already configured" -ForegroundColor Green
        } else {
            try {
                Add-McpToJson -FilePath $claudeSettings -CmdName $CmdName
                Write-Host "  [OK] Claude Code: configured" -ForegroundColor Green
            } catch {
                Write-Host "  [!] Claude Code: auto-config failed, manual config needed" -ForegroundColor Yellow
                Write-Host "      Add to $claudeSettings`:"
                Write-Host "      { `"mcpServers`": { `"flutter-skill`": { `"command`": `"$CmdName`", `"args`": [`"server`"] } } }" -ForegroundColor Cyan
            }
        }
    }

    # Cursor
    $cursorDir = "$env:USERPROFILE\.cursor"
    $cursorConfig = "$cursorDir\mcp.json"
    if (Test-Path $cursorDir) {
        if ((Test-Path $cursorConfig) -and ((Get-Content $cursorConfig -Raw) -match "flutter-skill|flutter_skill")) {
            Write-Host "  [OK] Cursor: already configured" -ForegroundColor Green
        } else {
            try {
                Add-McpToJson -FilePath $cursorConfig -CmdName $CmdName
                Write-Host "  [OK] Cursor: configured" -ForegroundColor Green
            } catch {
                Write-Host "  [!] Cursor: auto-config failed, manual config needed" -ForegroundColor Yellow
                Write-Host "      Add to $cursorConfig`:"
                Write-Host "      { `"mcpServers`": { `"flutter-skill`": { `"command`": `"$CmdName`", `"args`": [`"server`"] } } }" -ForegroundColor Cyan
            }
        }
    }
}

function Test-Installation {
    param([string]$CmdName)

    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Blue

    try {
        $versionOutput = & $CmdName --version 2>&1
        Write-Host "  [OK] $CmdName $versionOutput" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [!] $CmdName not found in PATH" -ForegroundColor Yellow
        Write-Host "      You may need to restart your terminal"
        return $false
    }
}

function Show-Summary {
    param([string]$CmdName)

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Quick Start:"
    Write-Host "    1. Launch your Flutter app:"
    Write-Host "       $CmdName launch /path/to/flutter/app" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    2. Or configure as MCP server in your IDE:"
    Write-Host "       { `"command`": `"$CmdName`", `"args`": [`"server`"] }" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    3. Check environment health:"
    Write-Host "       $CmdName doctor" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Docs: https://pub.dev/packages/flutter_skill"
    Write-Host ""
}

# ========== Installation Methods ==========

Write-Host "Detecting best installation method..." -ForegroundColor Yellow
Write-Host ""

# Method 1: npm (Recommended)
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "[OK] npm detected, installing via npm (recommended)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Running: npm install -g flutter-skill-mcp"
    npm install -g flutter-skill-mcp

    $cmd = "flutter-skill-mcp"
    if (Get-Command flutter-skill -ErrorAction SilentlyContinue) {
        $cmd = "flutter-skill"
    }

    Test-Installation -CmdName $cmd

    Write-Host ""
    Write-Host "Setting up tool priority rules..." -ForegroundColor Blue
    Install-ToolPriorityRules

    Show-IdeConfig -CmdName $cmd
    Show-Summary -CmdName $cmd
    exit 0
}

# Method 2: Scoop
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Scoop detected, installing via scoop" -ForegroundColor Green
    Write-Host ""
    Write-Host "Running: scoop bucket add flutter-skill"
    scoop bucket add flutter-skill https://github.com/ai-dashboad/scoop-flutter-skill
    Write-Host "Running: scoop install flutter-skill"
    scoop install flutter-skill

    Test-Installation -CmdName "flutter-skill"

    Write-Host ""
    Write-Host "Setting up tool priority rules..." -ForegroundColor Blue
    Install-ToolPriorityRules

    Show-IdeConfig -CmdName "flutter-skill"
    Show-Summary -CmdName "flutter-skill"
    exit 0
}

# Method 3: Install from source (requires Dart/Flutter)
if ((Get-Command dart -ErrorAction SilentlyContinue) -or (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[!] npm or Scoop not detected" -ForegroundColor Yellow
    Write-Host "Installing from source using Dart (requires Flutter SDK)" -ForegroundColor Yellow
    Write-Host ""

    # Check Flutter
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Host "[X] Error: Flutter SDK not found" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install Flutter first: https://flutter.dev/docs/get-started/install"
        Write-Host ""
        Write-Host "Or use one of the following methods:"
        Write-Host "  npm install -g flutter-skill-mcp  (recommended)"
        Write-Host "  scoop install flutter-skill"
        exit 1
    }

    # Download source
    $InstallDir = "$env:USERPROFILE\.flutter-skill-src"

    if (-not (Test-Path $InstallDir)) {
        Write-Host "Cloning repository to $InstallDir ..."
        git clone https://github.com/ai-dashboad/flutter-skill.git $InstallDir
    } else {
        Write-Host "Updating source code..."
        Set-Location $InstallDir
        git pull origin main
    }

    Set-Location $InstallDir

    # Install dependencies
    Write-Host "Installing dependencies..."
    flutter pub get

    # Create batch file wrapper
    Write-Host "Creating executable..."
    $BinDir = "$env:USERPROFILE\bin"
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir | Out-Null
    }

    $WrapperContent = @"
@echo off
cd /d "$InstallDir"
dart run bin/flutter_skill.dart %*
"@

    $WrapperContent | Out-File -FilePath "$BinDir\flutter-skill.bat" -Encoding ASCII

    # Add to PATH
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$BinDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
        Write-Host ""
        Write-Host "  [OK] Added to PATH: $BinDir" -ForegroundColor Green
        Write-Host "  [!] Please restart your terminal to use flutter-skill command" -ForegroundColor Yellow
    }

    # Verify
    Write-Host ""
    Write-Host "  [OK] flutter-skill installed to $BinDir\flutter-skill.bat" -ForegroundColor Green

    Write-Host ""
    Write-Host "Setting up tool priority rules..." -ForegroundColor Blue
    Install-ToolPriorityRules

    Show-IdeConfig -CmdName "flutter-skill"
    Show-Summary -CmdName "flutter-skill"
    exit 0
}

# No installation method found
Write-Host "[X] Error: No available installation method found" -ForegroundColor Red
Write-Host ""
Write-Host "Please install one of the following tools:"
Write-Host "  1. npm  (recommended) - https://nodejs.org/"
Write-Host "  2. Scoop - https://scoop.sh/"
Write-Host "  3. Flutter SDK - https://flutter.dev/"
Write-Host ""
Write-Host "Then run this script again"
exit 1
