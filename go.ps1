# Claude Code + Quake Console — Quick Setup (Windows)
# Run: irm https://raw.githubusercontent.com/SpitOnYourFace/cc/master/go.ps1 | iex

function Info($msg)  { Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "[X]  $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   Claude Code + Quake Console Setup" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# ─── 0. Admin check ───────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Warn "Not running as Admin. Some installs may need elevation."
    Warn "If installs fail, right-click PowerShell > 'Run as Administrator' and re-run."
    Write-Host ""
}

# ─── 1. Check winget ──────────────────────────────────────
$hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
if (-not $hasWinget) {
    Warn "winget not found. You'll need to install dependencies manually."
    Warn "Get winget: https://aka.ms/getwinget"
}

# ─── 2. Git + Git Bash ────────────────────────────────────
$gitBash = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    Info "Git Bash found"
} else {
    if ($hasWinget) {
        Warn "Git not found. Installing..."
        try {
            winget install Git.Git --accept-package-agreements --accept-source-agreements --silent | Out-Null
            # Refresh PATH so we can detect it
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                         [System.Environment]::GetEnvironmentVariable("PATH", "User")
            if (Test-Path $gitBash) { Info "Git Bash installed" }
            else { Warn "Git installed but may need terminal restart to detect Git Bash" }
        } catch {
            Warn "Git install failed. Install manually: https://git-scm.com"
        }
    } else {
        Warn "Install Git manually: https://git-scm.com"
    }
}

# ─── 3. Node.js ───────────────────────────────────────────
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $nodeVer = & node -v
    $major = [int]($nodeVer -replace 'v' -split '\.')[0]
    if ($major -lt 18) {
        Fail "Node.js 18+ required (you have $nodeVer). Update: https://nodejs.org"
    }
    Info "Node.js found: $nodeVer"
} else {
    if ($hasWinget) {
        Warn "Node.js not found. Installing..."
        try {
            winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent | Out-Null
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                         [System.Environment]::GetEnvironmentVariable("PATH", "User")
            $node = Get-Command node -ErrorAction SilentlyContinue
            if ($node) {
                Info "Node.js installed: $(node -v)"
            } else {
                Fail "Node.js installed but not in PATH. Close this terminal, open a new one, and re-run the script."
            }
        } catch {
            Fail "Node.js install failed. Install manually: https://nodejs.org"
        }
    } else {
        Fail "Install Node.js 18+ from https://nodejs.org then re-run."
    }
}

# ─── 4. npm check ─────────────────────────────────────────
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) { Fail "npm not found. Reinstall Node.js: https://nodejs.org" }
Info "npm found: $(npm -v)"

# ─── 5. Install Nerd Font (CaskaydiaCove) ─────────────────
$fontCheck = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue).PSObject.Properties |
    Where-Object { $_.Name -like "*Caskaydia*" -or $_.Name -like "*CascadiaCode*Nerd*" }
# Also check user-installed fonts
if (-not $fontCheck) {
    $fontCheck = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue).PSObject.Properties |
        Where-Object { $_.Name -like "*Caskaydia*" -or $_.Name -like "*CascadiaCode*Nerd*" }
}

if ($fontCheck) {
    Info "CaskaydiaCove Nerd Font found"
} else {
    Warn "Installing CaskaydiaCove Nerd Font..."
    try {
        $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
        $tempZip = Join-Path $env:TEMP "CascadiaCode-NF.zip"
        $tempExtract = Join-Path $env:TEMP "CascadiaCode-NF"

        # Download
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $fontZipUrl -OutFile $tempZip -UseBasicParsing

        # Extract
        if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        # Install fonts (only the Mono variants we need)
        $shellApp = New-Object -ComObject Shell.Application
        $fontsFolder = $shellApp.Namespace(0x14) # Windows Fonts folder
        $installed = 0
        Get-ChildItem "$tempExtract\*.ttf" | Where-Object { $_.Name -like "*CaskaydiaCoveNerdFontMono*" -or $_.Name -like "*CaskaydiaCoveNFM*" } | ForEach-Object {
            $fontsFolder.CopyHere($_.FullName, 0x14) # 0x14 = no prompt + yes to all
            $installed++
        }
        # If no mono variants found, install all ttf files
        if ($installed -eq 0) {
            Get-ChildItem "$tempExtract\*.ttf" | ForEach-Object {
                $fontsFolder.CopyHere($_.FullName, 0x14)
                $installed++
            }
        }

        # Cleanup
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

        if ($installed -gt 0) { Info "CaskaydiaCove Nerd Font installed ($installed files)" }
        else { Warn "Font extraction found no .ttf files" }
    } catch {
        Warn "Font auto-install failed: $_"
        Warn "Download manually: https://www.nerdfonts.com/font-downloads (search CaskaydiaCove)"
    }
}

# ─── 6. Install Claude Code ───────────────────────────────
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    Info "Claude Code already installed, updating..."
    npm update -g @anthropic-ai/claude-code 2>&1 | Out-Null
} else {
    Info "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code 2>&1 | Out-Null
}

# Refresh PATH so we can find claude after npm install
$npmGlobalBin = & npm config get prefix 2>$null
if ($npmGlobalBin) {
    $env:PATH = "$npmGlobalBin;$env:PATH"
}
# Also add the standard npm global path
$npmAppData = Join-Path $env:APPDATA "npm"
if (Test-Path $npmAppData) {
    $env:PATH = "$npmAppData;$env:PATH"
}

$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    $ver = & claude --version 2>$null
    if ($ver) { Info "Claude Code ready: $ver" }
    else { Info "Claude Code installed" }
} else {
    Warn "Claude Code installed but 'claude' not found in PATH."
    Warn "Close this terminal, open a new one, then run: claude"
}

# ─── 7. Install Zsh + plugins ──────────────────────────────
$zshExe = "C:\Program Files\Git\usr\bin\zsh.exe"
if (Test-Path $zshExe) {
    Info "Zsh already installed"
} else {
    Info "Installing Zsh for Git..."
    try {
        # Download Zsh MSYS2 package
        $zshUrl = "https://mirror.msys2.org/msys/x86_64/zsh-5.9-5-x86_64.pkg.tar.zst"
        $zshZst = Join-Path $env:TEMP "zsh.pkg.tar.zst"
        $zshTar = Join-Path $env:TEMP "zsh.pkg.tar"
        $gitDir = "C:\Program Files\Git"

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zshUrl -OutFile $zshZst -UseBasicParsing

        # Decompress .zst using Python (pip install zstandard)
        $hasPython = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        if ($hasPython) {
            python -m pip install --quiet zstandard 2>$null
            $pyScript = @"
import zstandard
with open(r'$zshZst', 'rb') as f:
    data = zstandard.ZstdDecompressor().decompress(f.read(), max_output_size=50*1024*1024)
with open(r'$zshTar', 'wb') as o:
    o.write(data)
"@
            python -c $pyScript 2>$null
        }

        if (-not (Test-Path $zshTar)) {
            # Fallback: try native tar if it supports zstd
            tar --zstd -xf $zshZst -C $gitDir 2>$null
            if ($?) {
                Info "Zsh installed (native tar)"
            } else {
                Warn "Could not decompress .zst — install Python or zstd tool"
            }
        } else {
            # Extract tar into Git directory (needs admin for Program Files)
            if ($isAdmin) {
                tar -xf $zshTar -C $gitDir 2>$null
            } else {
                # Elevate for extraction
                Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile -Command `"tar -xf '$zshTar' -C '$gitDir'`""
            }

            if (Test-Path $zshExe) {
                Info "Zsh installed: $((& $zshExe --version 2>$null) -join ' ')"
            } else {
                Warn "Zsh extraction may have failed. Re-run as Admin."
            }
        }

        # Cleanup
        Remove-Item $zshZst -Force -ErrorAction SilentlyContinue
        Remove-Item $zshTar -Force -ErrorAction SilentlyContinue
    } catch {
        Warn "Zsh install failed: $_"
    }
}

# Install Zsh plugins
$zshPluginDir = Join-Path $env:USERPROFILE ".zsh\plugins"
if (-not (Test-Path $zshPluginDir)) {
    New-Item -ItemType Directory -Path $zshPluginDir -Force | Out-Null
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    # zsh-autosuggestions
    $autoDir = Join-Path $zshPluginDir "zsh-autosuggestions"
    if (-not (Test-Path $autoDir)) {
        Info "Installing zsh-autosuggestions..."
        git clone --quiet https://github.com/zsh-users/zsh-autosuggestions $autoDir 2>$null
        if (Test-Path $autoDir) { Info "zsh-autosuggestions installed" }
        else { Warn "zsh-autosuggestions clone failed" }
    } else { Info "zsh-autosuggestions already installed" }

    # zsh-syntax-highlighting
    $synDir = Join-Path $zshPluginDir "zsh-syntax-highlighting"
    if (-not (Test-Path $synDir)) {
        Info "Installing zsh-syntax-highlighting..."
        git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting $synDir 2>$null
        if (Test-Path $synDir) { Info "zsh-syntax-highlighting installed" }
        else { Warn "zsh-syntax-highlighting clone failed" }
    } else { Info "zsh-syntax-highlighting already installed" }
} else {
    Warn "git not found — cannot install Zsh plugins. Install Git first."
}

# Create .zshenv (runs BEFORE /etc/profile — suppresses bash git-completion error)
$zshenv = Join-Path $env:USERPROFILE ".zshenv"
if (-not (Test-Path $zshenv)) {
    $zshenvContent = @'
# Prevent Git for Windows from sourcing git-completion.bash in Zsh
export WINELOADERNOEXEC=1
'@
    [System.IO.File]::WriteAllText($zshenv, $zshenvContent, (New-Object System.Text.UTF8Encoding $false))
    Info "Created .zshenv (suppresses bash-only git-completion error)"
}

# Create .zshrc
$zshrc = Join-Path $env:USERPROFILE ".zshrc"
if (-not (Test-Path $zshrc) -or (Get-Content $zshrc -Raw) -notmatch "zsh-autosuggestions") {
    $zshrcContent = @'
# Zsh Core
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY APPEND_HISTORY
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ''

# Prompt
PROMPT='%F{green}InternetCodeSolutions%f@%F{cyan}MoneyMachine %F{yellow}%~%f$ '

# Plugins
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6B5D4F"
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Key bindings
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
'@
    [System.IO.File]::WriteAllText($zshrc, $zshrcContent, (New-Object System.Text.UTF8Encoding $false))
    Info "Created .zshrc with autosuggestions + syntax highlighting"
} else {
    Info ".zshrc already configured"
}

# ─── 8. Claude config directory + startup ──────────────────
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
"@ | Out-File -FilePath $startBat -Encoding ASCII -NoNewline
Info "Created start-claude.bat"

# Create CLAUDE.md preferences (no secrets)
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
if (-not (Test-Path $claudeMd)) {
    $mdContent = @"
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
"@
    # Write without BOM (clean UTF-8)
    [System.IO.File]::WriteAllText($claudeMd, $mdContent, (New-Object System.Text.UTF8Encoding $false))
    Info "Created CLAUDE.md preferences"
} else {
    Info "CLAUDE.md already exists, keeping yours"
}

# ─── 8. Windows Terminal — Quake Console Setup ─────────────
# Check both Store and non-Store paths for Windows Terminal
$wtPaths = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal")
)
$wtSettingsDir = $null
foreach ($p in $wtPaths) {
    if (Test-Path $p) { $wtSettingsDir = $p; break }
}

if (-not $wtSettingsDir) {
    # Windows Terminal not installed or never launched
    if ($hasWinget) {
        Warn "Windows Terminal not found. Installing..."
        try {
            winget install Microsoft.WindowsTerminal --accept-package-agreements --accept-source-agreements --silent | Out-Null
            Start-Sleep -Seconds 5

            # After install, try to launch WT briefly to create settings dir, then close it
            $wtExe = Get-Command wt -ErrorAction SilentlyContinue
            if ($wtExe) {
                Start-Process wt -ArgumentList "--help" -WindowStyle Hidden -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                # Check again
                foreach ($p in $wtPaths) {
                    if (Test-Path $p) { $wtSettingsDir = $p; break }
                }
            }

            if (-not $wtSettingsDir) {
                # Create the expected directory manually
                $wtSettingsDir = $wtPaths[0]
                New-Item -ItemType Directory -Path $wtSettingsDir -Force | Out-Null
            }
            Info "Windows Terminal installed"
        } catch {
            Warn "Windows Terminal install failed. Install from Microsoft Store."
        }
    } else {
        Warn "Install Windows Terminal from Microsoft Store, then re-run."
    }
}

if ($wtSettingsDir) {
    $wtSettingsPath = Join-Path $wtSettingsDir "settings.json"

    # Back up existing settings
    if (Test-Path $wtSettingsPath) {
        $backup = "$wtSettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $wtSettingsPath $backup
        Info "Backed up existing WT settings"
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
    "startOnUserLogin": true,
    "minimizeToNotificationArea": true,
    "alwaysShowNotificationIcon": true,
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
            "useAtlasEngine": false
        },
        "list":
        [
            {
                "commandline": "\"C:\\Program Files\\Git\\usr\\bin\\zsh.exe\" --login -i",
                "guid": "{a1b2c3d4-e5f6-7890-abcd-ef1234567890}",
                "hidden": false,
                "icon": "C:\\Program Files\\Git\\mingw64\\share\\git\\git-for-windows.ico",
                "name": "Zsh",
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
    # Write without BOM (WT can choke on BOM in some versions)
    [System.IO.File]::WriteAllText($wtSettingsPath, $wtSettings, (New-Object System.Text.UTF8Encoding $false))
    Info "Windows Terminal configured:"
    Info "  - Win + ``  = Quake dropdown console"
    Info "  - Default profile: Zsh"
    Info "  - Color scheme: Desert Storm"
    Info "  - Font: CaskaydiaCove NFM"
    Info "  - Claude Code profile added"

    # Launch WT in background so Win+` works immediately (no reboot needed)
    $wtProcess = Get-Process WindowsTerminal -ErrorAction SilentlyContinue
    if (-not $wtProcess) {
        Info "Starting Windows Terminal in background..."
        Start-Process wt -WindowStyle Hidden -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Info "Windows Terminal running — press Win + `` to toggle Quake console"
    } else {
        Info "Windows Terminal already running — Win + `` ready"
    }
}

# ─── Done ──────────────────────────────────────────────────
Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Info "SETUP COMPLETE!"
Write-Host ""
Write-Host "  What's ready:" -ForegroundColor White
Write-Host "    - Win + ``  = Quake dropdown console" -ForegroundColor Gray
Write-Host "    - Zsh as default shell (autosuggestions + syntax highlighting)" -ForegroundColor Gray
Write-Host "    - Desert Storm theme + Nerd Font" -ForegroundColor Gray
Write-Host "    - Claude Code profile in terminal" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next: Run 'claude' to log in (OAuth)" -ForegroundColor Yellow
Write-Host "  No API keys or secrets stored." -ForegroundColor Gray
Write-Host ""
if (-not $isAdmin) {
    Write-Host "  TIP: If something didn't install, re-run as Admin." -ForegroundColor Yellow
}
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
