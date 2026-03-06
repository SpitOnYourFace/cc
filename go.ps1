# Claude Code + Quake Console — Quick Setup (Windows)
# Run: irm <GIST_RAW_URL> | iex
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

function Info($msg)  { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "[X]  $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   Claude Code + Quake Console Setup" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Git Bash ───────────────────────────────────────────
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    Info "Git Bash found"
} else {
    Warn "Git Bash not found. Installing via winget..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install Git.Git --accept-package-agreements --accept-source-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                     [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if (Test-Path $gitBash) { Info "Git Bash installed" }
        else { Warn "Git installed — you may need to restart terminal" }
    } else {
        Warn "Install Git from https://git-scm.com then re-run for Git Bash profile"
    }
}

# ─── 2. Node.js ───────────────────────────────────────────
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nodeVer = & node -v
    Info "Node.js found: $nodeVer"
    $major = [int]($nodeVer -replace 'v' -split '\.')[0]
    if ($major -lt 18) {
        Fail "Node.js 18+ required (you have $nodeVer). Update: https://nodejs.org"
    }
} else {
    Warn "Node.js not found. Installing via winget..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                     [System.Environment]::GetEnvironmentVariable("PATH", "User")
        $node = Get-Command node -ErrorAction SilentlyContinue
        if (-not $node) {
            Fail "Node.js installed but not in PATH. Restart terminal and re-run."
        }
        Info "Node.js installed: $(node -v)"
    } else {
        Fail "Install Node.js 18+ from https://nodejs.org then re-run."
    }
}

# ─── 3. npm check ─────────────────────────────────────────
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) { Fail "npm not found. Reinstall Node.js: https://nodejs.org" }
Info "npm found: $(npm -v)"

# ─── 4. Install Nerd Font (CaskaydiaCove) ─────────────────
$fontName = "CaskaydiaCove NFM"
$fontInstalled = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue).PSObject.Properties |
    Where-Object { $_.Value -like "*CaskaydiaCove*" }
if ($fontInstalled) {
    Info "CaskaydiaCove Nerd Font found"
} else {
    Warn "Installing CaskaydiaCove Nerd Font..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install Nerdfont.CascadiaCode --accept-package-agreements --accept-source-agreements 2>$null
        if ($?) { Info "CaskaydiaCove Nerd Font installed" }
        else { Warn "Font install failed — download from: https://www.nerdfonts.com/font-downloads" }
    } else {
        Warn "Download CaskaydiaCove Nerd Font from: https://www.nerdfonts.com/font-downloads"
    }
}

# ─── 5. Install Claude Code ───────────────────────────────
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    Info "Claude Code already installed, updating..."
    npm update -g @anthropic-ai/claude-code
} else {
    Info "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
}
$ver = & claude --version 2>$null
if ($ver) { Info "Claude Code installed: $ver" }
else { Info "Claude Code installed" }

# ─── 6. Claude config directory + startup ──────────────────
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# Create Claude startup batch file
$startBat = Join-Path $claudeDir "start-claude.bat"
@"
@echo off
cd /d "%USERPROFILE%"
claude
"@ | Out-File -FilePath $startBat -Encoding ASCII
Info "Created start-claude.bat"

# Create CLAUDE.md preferences (no secrets)
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
if (-not (Test-Path $claudeMd)) {
    @"
# Global Claude Code Preferences

## General Code Style
- Indentation: 2 spaces (JS/TS/CSS/HTML)
- Use semicolons in JavaScript/TypeScript
- Single quotes for strings
- Trailing commas in multiline arrays/objects
- Files: kebab-case.ts, PascalCase.astro (components)

## Git Workflow
- Commit format: ``type: description`` (lowercase, imperative)
- Types: feat, fix, refactor, docs, style, test, chore

## Code Preferences
- Prefer const over let, avoid var
- Arrow functions for callbacks
- async/await over raw promises
- Template literals over concatenation
"@ | Out-File -FilePath $claudeMd -Encoding UTF8
    Info "Created CLAUDE.md preferences"
} else {
    Info "CLAUDE.md already exists, keeping yours"
}

# ─── 7. Windows Terminal — Quake Console Setup ─────────────
$wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtInstalled = Test-Path (Split-Path $wtSettingsPath)

if (-not $wtInstalled) {
    Warn "Windows Terminal not found. Installing..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        winget install Microsoft.WindowsTerminal --accept-package-agreements --accept-source-agreements
        Start-Sleep -Seconds 3
        $wtInstalled = Test-Path (Split-Path $wtSettingsPath)
        if ($wtInstalled) { Info "Windows Terminal installed" }
        else { Warn "Windows Terminal installed — restart may be needed" }
    } else {
        Warn "Install Windows Terminal from Microsoft Store"
    }
}

if ($wtInstalled) {
    # Back up existing settings
    if (Test-Path $wtSettingsPath) {
        $backup = "$wtSettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $wtSettingsPath $backup
        Info "Backed up existing WT settings to $backup"
    }

    $wtSettings = @'
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "actions":
    [
        { "command": { "action": "copy", "singleLine": false }, "id": "User.copy.644BA8F2" },
        { "command": "paste", "id": "User.paste" },
        { "command": { "action": "splitPane", "split": "auto", "splitMode": "duplicate" }, "id": "User.splitPane.A6751878" },
        { "command": "find", "id": "User.find" }
    ],
    "centerOnLaunch": true,
    "copyFormatting": "none",
    "copyOnSelect": false,
    "defaultProfile": "{a1b2c3d4-e5f6-7890-abcd-ef1234567890}",
    "initialCols": 120,
    "initialRows": 35,
    "keybindings":
    [
        { "id": "Terminal.QuakeMode", "keys": "win+`" },
        { "id": "User.copy.644BA8F2", "keys": "ctrl+c" },
        { "id": "User.find", "keys": "ctrl+shift+f" },
        { "id": "User.paste", "keys": "ctrl+v" },
        { "id": "User.splitPane.A6751878", "keys": "alt+shift+d" }
    ],
    "launchMode": "default",
    "newTabMenu": [ { "type": "remainingProfiles" } ],
    "profiles":
    {
        "defaults":
        {
            "colorScheme": "Desert Storm",
            "cursorShape": "bar",
            "font": { "face": "CaskaydiaCove NFM", "size": 11 },
            "opacity": 90,
            "padding": "8, 8, 8, 8",
            "scrollbarState": "hidden",
            "useAcrylic": false,
            "useAtlasEngine": true
        },
        "list":
        [
            {
                "commandline": "\"C:\\Program Files\\Git\\bin\\bash.exe\" --login -i",
                "guid": "{a1b2c3d4-e5f6-7890-abcd-ef1234567890}",
                "hidden": false,
                "icon": "C:\\Program Files\\Git\\mingw64\\share\\git\\git-for-windows.ico",
                "name": "Git Bash",
                "startingDirectory": "%USERPROFILE%"
            },
            {
                "commandline": "cmd.exe /c \"%USERPROFILE%\\.claude\\start-claude.bat\"",
                "guid": "{c1a2d3e4-f5a6-b7c8-d9e0-f1a2b3c4d5e6}",
                "hidden": false,
                "name": "Claude Code",
                "startingDirectory": "%USERPROFILE%",
                "icon": "ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png"
            },
            {
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": false,
                "name": "Windows PowerShell",
                "startingDirectory": "%USERPROFILE%"
            },
            {
                "commandline": "%SystemRoot%\\System32\\cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "hidden": false,
                "name": "Command Prompt"
            }
        ]
    },
    "schemes":
    [
        {
            "background": "#1A1510",
            "black": "#2A1F1A",
            "blue": "#7A8F9E",
            "brightBlack": "#6B5D4F",
            "brightBlue": "#A0B8CC",
            "brightCyan": "#F4C896",
            "brightGreen": "#C9B95B",
            "brightPurple": "#D9B87A",
            "brightRed": "#FF8855",
            "brightWhite": "#FFF8E7",
            "brightYellow": "#FFCC66",
            "cursorColor": "#FFCC66",
            "cyan": "#D4A574",
            "foreground": "#E8DCC0",
            "green": "#9B8B4F",
            "name": "Desert Storm",
            "purple": "#B89968",
            "red": "#CC6633",
            "selectionBackground": "#8B7355",
            "white": "#E8DCC0",
            "yellow": "#E8B339"
        }
    ],
    "themes": []
}
'@

    $wtSettings | Out-File -FilePath $wtSettingsPath -Encoding UTF8
    Info "Windows Terminal configured with Quake Mode (Win + ``)"
    Info "  - Default profile: Git Bash"
    Info "  - Color scheme: Desert Storm"
    Info "  - Font: CaskaydiaCove NFM"
    Info "  - Claude Code profile added"
}

# ─── Done ──────────────────────────────────────────────────
Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Info "SETUP COMPLETE!"
Write-Host ""
Write-Host "  What's ready:" -ForegroundColor White
Write-Host "    - Win + ``  = Quake dropdown console" -ForegroundColor Gray
Write-Host "    - Git Bash as default shell" -ForegroundColor Gray
Write-Host "    - Desert Storm theme + Nerd Font" -ForegroundColor Gray
Write-Host "    - Claude Code profile in terminal" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next: Run 'claude' to log in (OAuth)" -ForegroundColor Yellow
Write-Host "  No API keys or secrets stored." -ForegroundColor Gray
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
