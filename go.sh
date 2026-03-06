#!/usr/bin/env bash
# Claude Code + Quake Console — Quick Setup (Mac/Linux)
# Run: curl -fsSL https://raw.githubusercontent.com/SpitOnYourFace/cc/master/go.sh | bash
set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC}  $1"; }
fail()  { echo -e "${RED}[X]${NC}  $1"; exit 1; }
skip()  { echo -e "${GRAY}[--]${NC} $1"; }

# Retry wrapper: retry CMD ARGS... (3 attempts, 5s between)
retry() {
  local n=1 max=3 delay=5 cmd="$@"
  while true; do
    "$@" && return 0
    if [ $n -ge $max ]; then
      warn "Command failed after $max attempts: $cmd"
      return 1
    fi
    warn "Attempt $n/$max failed, retrying in ${delay}s..."
    sleep $delay
    n=$((n + 1))
  done
}

# Package manager install wrapper (handles apt/dnf/pacman/zypper/snap)
pkg_install() {
  local pkg="$1"
  local installed=false

  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y "$pkg" 2>/dev/null && installed=true
    # Fallback to snap if apt failed
    if ! $installed && command -v snap &>/dev/null; then
      warn "apt failed, trying snap..."
      sudo snap install "$pkg" 2>/dev/null && installed=true
    fi
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$pkg" 2>/dev/null && installed=true
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "$pkg" 2>/dev/null && installed=true
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y "$pkg" 2>/dev/null && installed=true
  elif command -v apk &>/dev/null; then
    sudo apk add "$pkg" 2>/dev/null && installed=true
  elif command -v snap &>/dev/null; then
    sudo snap install "$pkg" 2>/dev/null && installed=true
  fi

  $installed
}

echo ""
echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   Claude Code + Quake Console Setup${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# ─── 0. Environment detection ─────────────────────────────
IS_LINUX=false
IS_MAC=false
HAS_DISPLAY=false
HAS_SUDO=false
IS_TILING_WM=false
IS_KDE=false
IS_GNOME=false
IS_WAYLAND=false
DE=""

if [[ "$OSTYPE" == "linux"* ]]; then
  IS_LINUX=true
elif [[ "$OSTYPE" == "darwin"* ]]; then
  IS_MAC=true
else
  warn "Detected OS: $OSTYPE — some features may not work"
fi

# Check sudo access (without prompting)
if sudo -n true 2>/dev/null; then
  HAS_SUDO=true
  info "sudo access: yes"
elif command -v sudo &>/dev/null; then
  # sudo exists but might need password — test with a prompt
  warn "sudo may require a password. You'll be prompted if needed."
  HAS_SUDO=true
else
  warn "No sudo available. Will skip system-level installs."
  HAS_SUDO=false
fi

# Check display server
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
  HAS_DISPLAY=true
fi

# Check Wayland
if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
  IS_WAYLAND=true
fi

# Detect desktop environment
if $IS_LINUX; then
  if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
  elif [ -n "$DESKTOP_SESSION" ]; then
    DE=$(echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]')
  elif [ -n "$XDG_SESSION_DESKTOP" ]; then
    DE=$(echo "$XDG_SESSION_DESKTOP" | tr '[:upper:]' '[:lower:]')
  fi

  # Detect tiling WMs
  if echo "$DE" | grep -qi "i3\|sway\|hyprland\|bspwm\|dwm\|awesome\|qtile\|xmonad\|herbstluftwm\|river"; then
    IS_TILING_WM=true
  fi

  # Detect KDE vs GNOME-family
  if echo "$DE" | grep -qi "kde\|plasma"; then
    IS_KDE=true
  elif echo "$DE" | grep -qi "gnome\|unity\|budgie\|cinnamon\|mate\|pantheon\|cosmic\|pop\|ubuntu"; then
    IS_GNOME=true
  fi

  if $HAS_DISPLAY; then
    info "Desktop: ${DE:-unknown}$(if $IS_WAYLAND; then echo ' (Wayland)'; fi)$(if $IS_TILING_WM; then echo ' [tiling WM]'; fi)"
  else
    info "No display detected (headless/SSH) — skipping GUI setup"
  fi
fi

# ─── 0b. Check basic tools ────────────────────────────────
MISSING_TOOLS=""
for tool in curl; do
  if ! command -v $tool &>/dev/null; then
    MISSING_TOOLS="$MISSING_TOOLS $tool"
  fi
done
if [ -n "$MISSING_TOOLS" ]; then
  if $HAS_SUDO; then
    warn "Installing missing tools:$MISSING_TOOLS"
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq && sudo apt-get install -y $MISSING_TOOLS 2>/dev/null
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y $MISSING_TOOLS 2>/dev/null
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm $MISSING_TOOLS 2>/dev/null
    fi
  else
    fail "Missing required tools:$MISSING_TOOLS — install them and re-run."
  fi
fi

# Check unzip (needed for font install)
if ! command -v unzip &>/dev/null; then
  warn "unzip not found — installing..."
  if $HAS_SUDO; then
    pkg_install unzip || warn "Could not install unzip — font install may fail"
  else
    warn "No sudo to install unzip — font install will be skipped"
  fi
fi

# ─── 0c. Proxy detection ──────────────────────────────────
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
  PROXY="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-$http_proxy}}}"
  info "Proxy detected: $PROXY"
  # Configure npm to use the proxy
  if command -v npm &>/dev/null; then
    npm config set proxy "$PROXY" 2>/dev/null || true
    npm config set https-proxy "$PROXY" 2>/dev/null || true
    info "npm proxy configured"
  fi
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
  NODE_INSTALLED=false

  if $IS_MAC; then
    if command -v brew &>/dev/null; then
      retry brew install node && NODE_INSTALLED=true
    else
      fail "Install Homebrew (https://brew.sh) or Node.js 18+ (https://nodejs.org) first."
    fi

  elif $IS_LINUX; then
    # Strategy 1: fnm (no sudo needed, gets latest LTS)
    if command -v curl &>/dev/null; then
      warn "Trying fnm (Fast Node Manager — no sudo needed)..."
      if curl -fsSL https://fnm.vercel.app/install 2>/dev/null | bash 2>/dev/null; then
        # fnm installs to different locations depending on version
        for fnm_path in "$HOME/.local/share/fnm" "$HOME/.fnm"; do
          if [ -d "$fnm_path" ]; then
            export PATH="$fnm_path:$PATH"
          fi
        done
        # Source shell config to pick up fnm
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
          if [ -f "$rc" ]; then
            source "$rc" 2>/dev/null || true
          fi
        done

        if command -v fnm &>/dev/null; then
          eval "$(fnm env --shell bash 2>/dev/null || fnm env 2>/dev/null)" 2>/dev/null || true
          if fnm install --lts 2>/dev/null; then
            fnm use lts-latest 2>/dev/null || fnm default lts-latest 2>/dev/null || true
            NODE_INSTALLED=true
          fi
        fi
      fi
    fi

    # Strategy 2: System package manager (needs sudo)
    if ! $NODE_INSTALLED && $HAS_SUDO; then
      warn "fnm didn't work, trying system package manager..."
      if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq 2>/dev/null
        sudo apt-get install -y nodejs npm 2>/dev/null && NODE_INSTALLED=true
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y nodejs npm 2>/dev/null && NODE_INSTALLED=true
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm nodejs npm 2>/dev/null && NODE_INSTALLED=true
      elif command -v zypper &>/dev/null; then
        sudo zypper install -y nodejs npm 2>/dev/null && NODE_INSTALLED=true
      elif command -v apk &>/dev/null; then
        sudo apk add nodejs npm 2>/dev/null && NODE_INSTALLED=true
      fi

      # Check version — distro Node might be too old
      if $NODE_INSTALLED && command -v node &>/dev/null; then
        DIST_VER=$(node -v | sed 's/v//' | cut -d. -f1)
        if [ "$DIST_VER" -lt 18 ]; then
          warn "System Node.js is v$(node -v) (too old). Removing and retrying..."
          NODE_INSTALLED=false
          # Try NodeSource as last resort
          if command -v apt-get &>/dev/null && command -v curl &>/dev/null; then
            warn "Trying NodeSource repository..."
            curl -fsSL https://deb.nodesource.com/setup_20.x 2>/dev/null | sudo -E bash - 2>/dev/null
            sudo apt-get install -y nodejs 2>/dev/null && NODE_INSTALLED=true
          fi
        fi
      fi
    fi

    # Strategy 3: No sudo, fnm failed — direct binary
    if ! $NODE_INSTALLED && ! $HAS_SUDO; then
      warn "No sudo and fnm failed. Trying direct binary download..."
      ARCH=$(uname -m)
      case "$ARCH" in
        x86_64)  NODE_ARCH="linux-x64" ;;
        aarch64) NODE_ARCH="linux-arm64" ;;
        armv7l)  NODE_ARCH="linux-armv7l" ;;
        *) fail "Unsupported architecture: $ARCH" ;;
      esac
      NODE_DIR="$HOME/.local/node"
      mkdir -p "$NODE_DIR"
      if curl -fsSL "https://nodejs.org/dist/v20.18.0/node-v20.18.0-${NODE_ARCH}.tar.xz" | tar -xJ --strip-components=1 -C "$NODE_DIR" 2>/dev/null; then
        export PATH="$NODE_DIR/bin:$PATH"
        # Add to shell profile
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
          if [ -f "$rc" ]; then
            if ! grep -q "/.local/node/bin" "$rc" 2>/dev/null; then
              echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> "$rc"
            fi
          fi
        done
        NODE_INSTALLED=true
        info "Node.js installed to ~/.local/node"
      fi
    fi

    if ! $NODE_INSTALLED; then
      fail "All Node.js install methods failed. Install manually: https://nodejs.org"
    fi
  fi

  # Final verification
  if ! command -v node &>/dev/null; then
    fail "Node.js installed but 'node' not in PATH. Open a new terminal and re-run."
  fi
  info "Node.js installed: $(node -v)"
fi

# ─── 2. npm check ─────────────────────────────────────────
if ! command -v npm &>/dev/null; then
  # npm might be in same dir as node
  NODE_BIN=$(dirname "$(command -v node 2>/dev/null)")
  if [ -x "$NODE_BIN/npm" ]; then
    export PATH="$NODE_BIN:$PATH"
  else
    fail "npm not found. Reinstall Node.js: https://nodejs.org"
  fi
fi
info "npm found: $(npm -v)"

# ─── 3. Install Claude Code ───────────────────────────────
NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "")
NEEDS_SUDO=false
if [ -n "$NPM_PREFIX" ] && [ -d "$NPM_PREFIX/lib" ] && [ ! -w "$NPM_PREFIX/lib" ]; then
  if $HAS_SUDO; then
    NEEDS_SUDO=true
  else
    # Can't sudo — set npm prefix to user dir
    warn "npm global dir not writable and no sudo. Setting up user-local npm..."
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null
    export PATH="$HOME/.npm-global/bin:$PATH"
    NPM_PREFIX="$HOME/.npm-global"
    # Persist the PATH addition
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
      if [ -f "$rc" ] && ! grep -q ".npm-global/bin" "$rc" 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$rc"
      fi
    done
  fi
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
  retry npm_cmd update -g @anthropic-ai/claude-code 2>&1 | tail -3 || true
else
  info "Installing Claude Code..."
  retry npm_cmd install -g @anthropic-ai/claude-code 2>&1 | tail -3 || true
fi

# Ensure claude is in PATH
if ! command -v claude &>/dev/null; then
  for p in "$NPM_PREFIX/bin" "$HOME/.npm-global/bin" "$HOME/.local/bin" "$HOME/.local/node/bin" "$HOME/.fnm/node-versions/"*/installation/bin; do
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
  if $IS_LINUX && ! $FONT_INSTALLED; then
    if command -v fc-list &>/dev/null && fc-list 2>/dev/null | grep -qi "CaskaydiaCove\|CascadiaCode.*Nerd"; then
      FONT_INSTALLED=true
      info "CaskaydiaCove Nerd Font found (system)"
    fi
  fi
fi

if ! $FONT_INSTALLED && [ -n "$FONT_DIR" ]; then
  if ! command -v unzip &>/dev/null; then
    warn "unzip not available — skipping font install."
    warn "Install manually: https://www.nerdfonts.com/font-downloads (CaskaydiaCove)"
  else
    warn "Installing CaskaydiaCove Nerd Font..."
    mkdir -p "$FONT_DIR"
    FONT_ZIP="/tmp/CascadiaCode-NF.zip"
    FONT_EXTRACT="/tmp/CascadiaCode-NF"

    if retry curl -fsSL -o "$FONT_ZIP" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"; then
      rm -rf "$FONT_EXTRACT"
      mkdir -p "$FONT_EXTRACT"
      if unzip -qo "$FONT_ZIP" -d "$FONT_EXTRACT" 2>/dev/null; then
        COPIED=0
        # Install mono variants first (what "CaskaydiaCove NFM" maps to)
        for f in "$FONT_EXTRACT"/*CaskaydiaCoveNerdFontMono*.ttf "$FONT_EXTRACT"/*CaskaydiaCoveNFM*.ttf; do
          if [ -f "$f" ]; then
            cp "$f" "$FONT_DIR/"
            COPIED=$((COPIED + 1))
          fi
        done
        # If no mono found, install all ttf
        if [ "$COPIED" -eq 0 ]; then
          for f in "$FONT_EXTRACT"/*.ttf; do
            if [ -f "$f" ]; then
              cp "$f" "$FONT_DIR/"
              COPIED=$((COPIED + 1))
            fi
          done
        fi

        # Refresh font cache
        if $IS_LINUX && command -v fc-cache &>/dev/null; then
          fc-cache -f "$FONT_DIR" 2>/dev/null || true
        fi

        if [ "$COPIED" -gt 0 ]; then
          info "CaskaydiaCove Nerd Font installed ($COPIED files)"
        else
          warn "Font zip extracted but no .ttf files found inside"
        fi
      else
        warn "unzip failed on font archive (corrupt download?)"
      fi

      # Cleanup
      rm -f "$FONT_ZIP"
      rm -rf "$FONT_EXTRACT"
    else
      warn "Font download failed. Get it manually: https://www.nerdfonts.com/font-downloads"
    fi
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
if $IS_LINUX && $HAS_DISPLAY; then

  # ── Tiling WM — skip Guake/Yakuake ─────────────────────
  if $IS_TILING_WM; then
    echo ""
    skip "Tiling WM detected ($DE) — skipping Guake/Yakuake."
    info "For a quake console on tiling WMs, use your WM's scratchpad:"
    case "$DE" in
      *i3*)
        info "  i3: bindsym \$mod+grave [instance=\"dropdown\"] scratchpad show"
        info "  Or install tdrop: tdrop -a -w 100% -h 50% alacritty"
        ;;
      *sway*)
        info "  Sway: bindsym \$mod+grave [app_id=\"dropdown\"] scratchpad show"
        ;;
      *hyprland*)
        info "  Hyprland: bind = SUPER, grave, togglespecialworkspace, term"
        ;;
      *)
        info "  Use 'tdrop' for WM-agnostic dropdown: tdrop -a -w 100% -h 50% alacritty"
        ;;
    esac

  # ── KDE → Yakuake ──────────────────────────────────────
  elif $IS_KDE; then
    echo ""
    info "Setting up Yakuake (KDE dropdown terminal)..."

    if ! command -v yakuake &>/dev/null; then
      if $HAS_SUDO; then
        warn "Installing Yakuake..."
        pkg_install yakuake || warn "Yakuake install failed — install manually"
      else
        warn "No sudo — install Yakuake manually: sudo apt install yakuake (or equivalent)"
      fi
    fi

    if command -v yakuake &>/dev/null; then
      info "Yakuake found"

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

      # Configure Yakuake
      YAKUAKE_RC="$HOME/.config/yakuakerc"
      mkdir -p "$(dirname "$YAKUAKE_RC")"

      # Preserve existing config if present, only set our keys
      if [ -f "$YAKUAKE_RC" ]; then
        cp "$YAKUAKE_RC" "$YAKUAKE_RC.backup-$(date +%Y%m%d-%H%M%S)"
        info "Backed up existing yakuakerc"
      fi

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
      info "  Default hotkey: F12"
      warn "  To use Super+\`: Yakuake > Menu > Configure Shortcuts > Open/Retract"
    fi

  # ── GNOME/others → Guake ───────────────────────────────
  else
    echo ""
    info "Setting up Guake (dropdown terminal)..."

    if ! command -v guake &>/dev/null; then
      if $HAS_SUDO; then
        warn "Installing Guake..."
        # Try apt first, then snap, then flatpak
        if ! pkg_install guake; then
          if command -v flatpak &>/dev/null; then
            warn "Trying Flatpak..."
            flatpak install -y flathub org.guake.guake 2>/dev/null || warn "Flatpak install also failed"
          fi
        fi
      else
        warn "No sudo — install Guake manually:"
        warn "  Ubuntu/Debian: sudo apt install guake"
        warn "  Fedora:        sudo dnf install guake"
        warn "  Arch:          sudo pacman -S guake"
      fi
    fi

    if command -v guake &>/dev/null; then
      info "Guake found"

      # Install dconf if missing (needed for config)
      if ! command -v dconf &>/dev/null; then
        if $HAS_SUDO; then
          warn "dconf not found — installing..."
          pkg_install dconf-cli 2>/dev/null || pkg_install dconf 2>/dev/null || true
        fi
      fi

      if command -v dconf &>/dev/null; then
        # ── Detect Guake version for correct dconf paths ──
        GUAKE_VER=$(guake --version 2>/dev/null | grep -oP '[\d]+\.[\d]+' | head -1 || echo "3")
        GUAKE_MAJOR=$(echo "$GUAKE_VER" | cut -d. -f1)

        # Guake 3.x uses /apps/guake/ paths
        # Older Guake uses /apps/guake/ too but with slightly different keys
        GUAKE_PREFIX="/apps/guake"

        # Hotkey: F12 (reliable on all GNOME versions, X11 and Wayland)
        dconf write "$GUAKE_PREFIX/keybindings/global/show-hide" "'F12'" 2>/dev/null || true

        # Font
        dconf write "$GUAKE_PREFIX/style/font/style" "'CaskaydiaCove NFM 11'" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/style/font/allow-bold" "true" 2>/dev/null || true

        # Window
        dconf write "$GUAKE_PREFIX/general/window-height" "50" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/general/window-width" "100" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/general/use-scrollbar" "false" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/general/use-popup" "false" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/general/start-at-login" "true" 2>/dev/null || true

        # Transparency
        dconf write "$GUAKE_PREFIX/style/background/transparency" "90" 2>/dev/null || true

        # Desert Storm palette
        PALETTE="'#2A2A1F1F1A1A:#CCCC66663333:#9B9B8B8B4F4F:#E8E8B3B33939:#7A7A8F8F9E9E:#B8B899996868:#D4D4A5A57474:#E8E8DCDCC0C0:#6B6B5D5D4F4F:#FFFF88885555:#C9C9B9B95B5B:#FFFFCCCC6666:#A0A0B8B8CCCC:#D9D9B8B87A7A:#F4F4C8C89696:#FFFFF8F8E7E7'"
        dconf write "$GUAKE_PREFIX/style/font/palette" "$PALETTE" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/style/font/palette-name" "'Custom'" 2>/dev/null || true

        # Background and foreground
        dconf write "$GUAKE_PREFIX/style/font/color" "'#E8E8DCDCC0C0'" 2>/dev/null || true
        dconf write "$GUAKE_PREFIX/style/background/color" "'#1A1A15151010'" 2>/dev/null || true

        info "Guake configured:"
        info "  - Hotkey: F12"
        info "  - Color scheme: Desert Storm"
        info "  - Font: CaskaydiaCove NFM 11"
        info "  - 90% opacity, no scrollbar"
      else
        warn "dconf not available — Guake installed but not auto-configured."
        warn "Open Guake Preferences manually to set theme/font/hotkey."
      fi

      # Add Guake to autostart
      AUTOSTART_DIR="$HOME/.config/autostart"
      mkdir -p "$AUTOSTART_DIR"
      if [ ! -f "$AUTOSTART_DIR/guake.desktop" ]; then
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
StartupNotify=false
EOF
        info "Guake added to autostart"
      fi

    else
      warn "Guake not available. Install manually then re-run, or use a different dropdown terminal."
    fi
  fi

elif $IS_LINUX && ! $HAS_DISPLAY; then
  skip "Headless/SSH session — skipping Quake console setup."
  skip "Run this script again in a desktop session for terminal setup."

elif $IS_MAC; then
  echo ""
  skip "Quake console not auto-configured on macOS."
  info "For a similar experience, use iTerm2 with Hotkey Window:"
  info "  1. brew install --cask iterm2"
  info "  2. Preferences > Keys > Hotkey > Create Dedicated Hotkey Window"
  info "  3. Set hotkey to Cmd+\`"
  info "  Or use Alacritty + skhd for a lightweight alternative."
fi

# ─── Done ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=======================================${NC}"
info "SETUP COMPLETE!"
echo ""
echo "  What's ready:"
if $IS_LINUX && $HAS_DISPLAY; then
  if $IS_TILING_WM; then
    echo "    - Scratchpad instructions for $DE"
  elif $IS_KDE; then
    echo "    - Yakuake dropdown terminal (F12)"
  else
    echo "    - Guake dropdown terminal (F12)"
  fi
  echo "    - Desert Storm color scheme"
  echo "    - CaskaydiaCove Nerd Font"
fi
echo "    - Claude Code CLI"
echo "    - CLAUDE.md preferences"
echo ""
echo -e "  ${YELLOW}Next: Run 'claude' to log in (OAuth)${NC}"
echo "  No API keys or secrets stored."
if ! $HAS_SUDO; then
  echo ""
  echo -e "  ${YELLOW}TIP: Some installs were skipped (no sudo).${NC}"
  echo -e "  ${YELLOW}Re-run with sudo access for full setup.${NC}"
fi
echo -e "${CYAN}=======================================${NC}"
echo ""
