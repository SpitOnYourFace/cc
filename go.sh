#!/usr/bin/env bash
# Claude Code + Quake Console — Quick Setup (Mac/Linux)
# Run: curl -fsSL https://raw.githubusercontent.com/SpitOnYourFace/cc/master/go.sh | bash
set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC}  $1"; }
fail()  { echo -e "${RED}[X]${NC}  $1"; exit 1; }

echo ""
echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   Claude Code + Quake Console Setup${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

IS_LINUX=false
IS_MAC=false
if [[ "$OSTYPE" == "linux"* ]]; then
  IS_LINUX=true
elif [[ "$OSTYPE" == "darwin"* ]]; then
  IS_MAC=true
fi

# Detect desktop environment (Linux)
DE=""
if $IS_LINUX; then
  if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
  elif [ -n "$DESKTOP_SESSION" ]; then
    DE=$(echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]')
  fi
  info "Detected DE: ${DE:-unknown}"
fi

# ─── 1. Node.js ───────────────────────────────────────────
if command -v node &>/dev/null; then
  NODE_VER=$(node -v)
  MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [ "$MAJOR" -lt 18 ]; then
    fail "Node.js 18+ required (you have $NODE_VER). Update: https://nodejs.org"
  fi
  info "Node.js found: $NODE_VER"
else
  warn "Node.js not found. Installing..."
  if $IS_MAC; then
    if command -v brew &>/dev/null; then
      brew install node
    else
      fail "Install Homebrew first (https://brew.sh) or Node.js 18+: https://nodejs.org"
    fi
  elif $IS_LINUX; then
    if command -v curl &>/dev/null; then
      warn "Installing via fnm (Fast Node Manager)..."
      curl -fsSL https://fnm.vercel.app/install | bash
      # Source fnm into current session
      export PATH="$HOME/.local/share/fnm:$PATH"
      if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
      fi
      if command -v fnm &>/dev/null; then
        eval "$(fnm env)"
        fnm install --lts
        fnm use lts-latest 2>/dev/null || fnm use default
      else
        # Fallback to system package manager
        if command -v apt-get &>/dev/null; then
          warn "fnm failed, trying apt..."
          sudo apt-get update -qq && sudo apt-get install -y nodejs npm
        elif command -v dnf &>/dev/null; then
          sudo dnf install -y nodejs npm
        elif command -v pacman &>/dev/null; then
          sudo pacman -S --noconfirm nodejs npm
        elif command -v zypper &>/dev/null; then
          sudo zypper install -y nodejs npm
        else
          fail "Install Node.js 18+ manually: https://nodejs.org"
        fi
      fi
    else
      fail "curl not found. Run: sudo apt install curl (or equivalent) then re-run."
    fi
  else
    fail "Unsupported OS. Install Node.js 18+ manually: https://nodejs.org"
  fi

  if ! command -v node &>/dev/null; then
    fail "Node.js installed but 'node' not in PATH. Open a new terminal and re-run."
  fi
  info "Node.js installed: $(node -v)"
fi

# ─── 2. npm check ─────────────────────────────────────────
if ! command -v npm &>/dev/null; then
  fail "npm not found. Reinstall Node.js: https://nodejs.org"
fi
info "npm found: $(npm -v)"

# ─── 3. Install Claude Code ───────────────────────────────
NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "")
NEEDS_SUDO=false
if [ -n "$NPM_PREFIX" ] && [ -d "$NPM_PREFIX/lib" ] && [ ! -w "$NPM_PREFIX/lib" ]; then
  NEEDS_SUDO=true
fi

npm_cmd() {
  if $NEEDS_SUDO; then
    sudo npm "$@"
  else
    npm "$@"
  fi
}

if command -v claude &>/dev/null; then
  info "Claude Code already installed, updating..."
  npm_cmd update -g @anthropic-ai/claude-code 2>&1 | tail -1 || true
else
  info "Installing Claude Code..."
  npm_cmd install -g @anthropic-ai/claude-code 2>&1 | tail -1 || true
fi

# Ensure claude is in PATH
if ! command -v claude &>/dev/null; then
  for p in "$NPM_PREFIX/bin" "$HOME/.local/bin" "$HOME/.npm-global/bin" "$HOME/.fnm/node-versions/"*/installation/bin; do
    if [ -x "$p/claude" ]; then
      export PATH="$p:$PATH"
      break
    fi
  done
fi

if command -v claude &>/dev/null; then
  info "Claude Code ready: $(claude --version 2>/dev/null || echo 'installed')"
else
  warn "Claude Code installed but 'claude' not in PATH."
  warn "Open a new terminal, then run: claude"
fi

# ─── 4. Install CaskaydiaCove Nerd Font ───────────────────
FONT_DIR=""
FONT_INSTALLED=false

if $IS_LINUX; then
  FONT_DIR="$HOME/.local/share/fonts"
elif $IS_MAC; then
  FONT_DIR="$HOME/Library/Fonts"
fi

# Check if already installed
if [ -n "$FONT_DIR" ]; then
  if ls "$FONT_DIR"/*CaskaydiaCove* &>/dev/null 2>&1 || ls "$FONT_DIR"/*CascadiaCode* &>/dev/null 2>&1; then
    FONT_INSTALLED=true
    info "CaskaydiaCove Nerd Font found"
  fi
  # Also check system fonts on Linux
  if $IS_LINUX && ! $FONT_INSTALLED; then
    if fc-list 2>/dev/null | grep -qi "CaskaydiaCove\|CascadiaCode.*Nerd"; then
      FONT_INSTALLED=true
      info "CaskaydiaCove Nerd Font found (system)"
    fi
  fi
fi

if ! $FONT_INSTALLED && [ -n "$FONT_DIR" ]; then
  warn "Installing CaskaydiaCove Nerd Font..."
  mkdir -p "$FONT_DIR"
  FONT_ZIP="/tmp/CascadiaCode-NF.zip"
  FONT_EXTRACT="/tmp/CascadiaCode-NF"

  if curl -fsSL -o "$FONT_ZIP" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"; then
    rm -rf "$FONT_EXTRACT"
    mkdir -p "$FONT_EXTRACT"
    unzip -qo "$FONT_ZIP" -d "$FONT_EXTRACT" 2>/dev/null || true

    # Install mono variants (what "CaskaydiaCove NFM" uses)
    COPIED=0
    for f in "$FONT_EXTRACT"/*CaskaydiaCoveNerdFontMono*.ttf "$FONT_EXTRACT"/*CaskaydiaCoveNFM*.ttf; do
      if [ -f "$f" ]; then
        cp "$f" "$FONT_DIR/"
        COPIED=$((COPIED + 1))
      fi
    done
    # If no mono found, install all
    if [ "$COPIED" -eq 0 ]; then
      for f in "$FONT_EXTRACT"/*.ttf; do
        if [ -f "$f" ]; then
          cp "$f" "$FONT_DIR/"
          COPIED=$((COPIED + 1))
        fi
      done
    fi

    # Refresh font cache on Linux
    if $IS_LINUX && command -v fc-cache &>/dev/null; then
      fc-cache -f "$FONT_DIR" 2>/dev/null || true
    fi

    # Cleanup
    rm -f "$FONT_ZIP"
    rm -rf "$FONT_EXTRACT"

    if [ "$COPIED" -gt 0 ]; then
      info "CaskaydiaCove Nerd Font installed ($COPIED files)"
    else
      warn "Font zip downloaded but no .ttf files found"
    fi
  else
    warn "Font download failed. Get it manually: https://www.nerdfonts.com/font-downloads"
  fi
fi

# ─── 5. Claude config directory + preferences ─────────────
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cat > "$CLAUDE_DIR/CLAUDE.md" << 'CLAUDEMD'
# Global Claude Code Preferences

## General Code Style
- Indentation: 2 spaces (JS/TS/CSS/HTML)
- Use semicolons in JavaScript/TypeScript
- Single quotes for strings
- Trailing commas in multiline arrays/objects
- Files: kebab-case.ts, PascalCase.astro (components)

## Git Workflow
- Commit format: `type: description` (lowercase, imperative)
- Types: feat, fix, refactor, docs, style, test, chore

## Code Preferences
- Prefer const over let, avoid var
- Arrow functions for callbacks
- async/await over raw promises
- Template literals over concatenation
CLAUDEMD
  info "Created CLAUDE.md preferences"
else
  info "CLAUDE.md already exists, keeping yours"
fi

# ─── 6. Quake Console (Linux only) ────────────────────────
if $IS_LINUX; then
  echo ""
  info "Setting up Quake dropdown terminal..."

  IS_KDE=false
  IS_GNOME=false
  if echo "$DE" | grep -qi "kde\|plasma"; then
    IS_KDE=true
  elif echo "$DE" | grep -qi "gnome\|unity\|budgie\|cinnamon\|mate\|pantheon"; then
    IS_GNOME=true
  fi

  # ── KDE → Yakuake ──────────────────────────────────────
  if $IS_KDE; then
    if command -v yakuake &>/dev/null; then
      info "Yakuake found"
    else
      warn "Installing Yakuake..."
      if command -v apt-get &>/dev/null; then
        sudo apt-get install -y yakuake 2>/dev/null || warn "Yakuake install failed"
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y yakuake 2>/dev/null || warn "Yakuake install failed"
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm yakuake 2>/dev/null || warn "Yakuake install failed"
      elif command -v zypper &>/dev/null; then
        sudo zypper install -y yakuake 2>/dev/null || warn "Yakuake install failed"
      fi
      if command -v yakuake &>/dev/null; then
        info "Yakuake installed"
      fi
    fi

    # Create Konsole profile with Desert Storm
    KONSOLE_DIR="$HOME/.local/share/konsole"
    mkdir -p "$KONSOLE_DIR"
    cat > "$KONSOLE_DIR/DesertStorm.profile" << 'EOF'
[Appearance]
ColorScheme=DesertStorm
Font=CaskaydiaCove NFM,11,-1,5,50,0,0,0,0,0

[General]
Name=DesertStorm
Parent=FALLBACK/

[Scrolling]
ScrollBarPosition=2
EOF

    # Create Desert Storm color scheme for Konsole
    cat > "$KONSOLE_DIR/DesertStorm.colorscheme" << 'EOF'
[Background]
Color=26,21,16

[BackgroundFaint]
Color=26,21,16

[BackgroundIntense]
Color=26,21,16

[Color0]
Color=42,31,26

[Color0Faint]
Color=42,31,26

[Color0Intense]
Color=107,93,79

[Color1]
Color=204,102,51

[Color1Faint]
Color=204,102,51

[Color1Intense]
Color=255,136,85

[Color2]
Color=155,139,79

[Color2Faint]
Color=155,139,79

[Color2Intense]
Color=201,185,91

[Color3]
Color=232,179,57

[Color3Faint]
Color=232,179,57

[Color3Intense]
Color=255,204,102

[Color4]
Color=122,143,158

[Color4Faint]
Color=122,143,158

[Color4Intense]
Color=160,184,204

[Color5]
Color=184,153,104

[Color5Faint]
Color=184,153,104

[Color5Intense]
Color=217,184,122

[Color6]
Color=212,165,116

[Color6Faint]
Color=212,165,116

[Color6Intense]
Color=244,200,150

[Color7]
Color=232,220,192

[Color7Faint]
Color=232,220,192

[Color7Intense]
Color=255,248,231

[Foreground]
Color=232,220,192

[ForegroundFaint]
Color=232,220,192

[ForegroundIntense]
Color=255,248,231

[General]
Blur=false
ColorRandomization=false
Description=Desert Storm
Opacity=0.9
Wallpaper=
EOF

    # Configure Yakuake to use DesertStorm profile
    YAKUAKE_RC="$HOME/.config/yakuakerc"
    mkdir -p "$(dirname "$YAKUAKE_RC")"
    cat > "$YAKUAKE_RC" << 'EOF'
[Desktop Entry]
DefaultProfile=DesertStorm.profile

[Dialogs]
FirstRun=false

[Window]
KeepOpen=false
Width=100
Height=50
EOF

    info "Yakuake configured with Desert Storm theme"
    info "  Hotkey: F12 (default) — change in Yakuake settings to Super+\`"
    warn "  To change hotkey: Yakuake > Menu > Configure Shortcuts > Open/Retract"

  # ── GNOME/others → Guake ───────────────────────────────
  else
    if command -v guake &>/dev/null; then
      info "Guake found"
    else
      warn "Installing Guake..."
      if command -v apt-get &>/dev/null; then
        sudo apt-get install -y guake 2>/dev/null || warn "Guake install failed"
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y guake 2>/dev/null || warn "Guake install failed"
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm guake 2>/dev/null || warn "Guake install failed"
      elif command -v zypper &>/dev/null; then
        sudo zypper install -y guake 2>/dev/null || warn "Guake install failed"
      fi
      if command -v guake &>/dev/null; then
        info "Guake installed"
      fi
    fi

    # Configure Guake via dconf (if available)
    if command -v dconf &>/dev/null && command -v guake &>/dev/null; then
      # Hotkey: Super + ` (grave)
      dconf write /apps/guake/keybindings/global/show-hide "'<Super>grave'" 2>/dev/null || true

      # Font
      dconf write /apps/guake/style/font/style "'CaskaydiaCove NFM 11'" 2>/dev/null || true
      dconf write /apps/guake/style/font/allow-bold "true" 2>/dev/null || true

      # Window
      dconf write /apps/guake/general/window-height "50" 2>/dev/null || true
      dconf write /apps/guake/general/window-width "100" 2>/dev/null || true
      dconf write /apps/guake/general/use-scrollbar "false" 2>/dev/null || true
      dconf write /apps/guake/general/use-popup "false" 2>/dev/null || true
      dconf write /apps/guake/general/start-at-login "true" 2>/dev/null || true

      # Transparency
      dconf write /apps/guake/style/background/transparency "90" 2>/dev/null || true

      # Desert Storm palette (16 colors: black,red,green,yellow,blue,purple,cyan,white + bright variants)
      # Format: '#RRRRGGGGBBBB' per color, colon-separated
      PALETTE="'#2A2A1F1F1A1A:#CCCC66663333:#9B9B8B8B4F4F:#E8E8B3B33939:#7A7A8F8F9E9E:#B8B899996868:#D4D4A5A57474:#E8E8DCDCC0C0:#6B6B5D5D4F4F:#FFFF88885555:#C9C9B9B95B5B:#FFFFCCCC6666:#A0A0B8B8CCCC:#D9D9B8B87A7A:#F4F4C8C89696:#FFFFF8F8E7E7'"
      dconf write /apps/guake/style/font/palette "$PALETTE" 2>/dev/null || true
      dconf write /apps/guake/style/font/palette-name "'Custom'" 2>/dev/null || true

      # Background and foreground
      dconf write /apps/guake/style/font/color "'#E8E8DCDCC0C0'" 2>/dev/null || true
      dconf write /apps/guake/style/background/color "'#1A1A15151010'" 2>/dev/null || true

      info "Guake configured:"
      info "  - Hotkey: Super + \` (backtick)"
      info "  - Color scheme: Desert Storm"
      info "  - Font: CaskaydiaCove NFM 11"
      info "  - 90% opacity, no scrollbar"

    elif command -v guake &>/dev/null; then
      warn "dconf not found — Guake installed but not auto-configured."
      warn "Open Guake Preferences to set theme/font/hotkey manually."
    fi

    # Add Guake to autostart
    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    if command -v guake &>/dev/null && [ ! -f "$AUTOSTART_DIR/guake.desktop" ]; then
      cat > "$AUTOSTART_DIR/guake.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Guake Terminal
Comment=Quake-style dropdown terminal
Exec=guake
Icon=guake
Terminal=false
Categories=System;TerminalEmulator;
X-GNOME-Autostart-enabled=true
EOF
      info "Guake added to autostart"
    fi
  fi

elif $IS_MAC; then
  echo ""
  warn "Quake console not auto-configured on macOS."
  warn "For a similar experience, use iTerm2 with Hotkey Window:"
  warn "  1. Install: brew install --cask iterm2"
  warn "  2. Preferences > Keys > Hotkey > Create Dedicated Hotkey Window"
  warn "  3. Set hotkey to Cmd+\`"
fi

# ─── Done ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=======================================${NC}"
info "SETUP COMPLETE!"
echo ""
echo "  What's ready:"
if $IS_LINUX; then
  if $IS_KDE; then
    echo "    - Yakuake dropdown terminal (F12)"
  else
    echo "    - Guake dropdown terminal (Super + \`)"
  fi
  echo "    - Desert Storm color scheme"
  echo "    - CaskaydiaCove Nerd Font"
fi
echo "    - Claude Code CLI"
echo "    - CLAUDE.md preferences"
echo ""
echo -e "  ${YELLOW}Next: Run 'claude' to log in (OAuth)${NC}"
echo "  No API keys or secrets stored."
echo -e "${CYAN}=======================================${NC}"
echo ""
