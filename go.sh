#!/usr/bin/env bash
# Claude Code Quick Setup — Mac/Linux
# Run: curl -fsSL https://raw.githubusercontent.com/SpitOnYourFace/cc/master/go.sh | bash
set -eo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC}  $1"; }
fail()  { echo -e "${RED}[X]${NC}  $1"; exit 1; }

echo ""
echo "======================================="
echo "   Claude Code — Quick Setup"
echo "======================================="
echo ""

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
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &>/dev/null; then
      brew install node
    else
      warn "Homebrew not found. Trying direct install..."
      fail "Install Node.js 18+: https://nodejs.org or install Homebrew first (https://brew.sh)"
    fi
  elif [[ "$OSTYPE" == "linux"* ]]; then
    # Try fnm first (modern, no sudo needed)
    if command -v curl &>/dev/null; then
      warn "Installing via fnm (Fast Node Manager)..."
      curl -fsSL https://fnm.vercel.app/install | bash
      export PATH="$HOME/.local/share/fnm:$PATH"
      if command -v fnm &>/dev/null; then
        eval "$(fnm env)"
        fnm install --lts
        fnm use lts-latest
      else
        # Fallback to system package manager
        if command -v apt-get &>/dev/null; then
          warn "Trying apt..."
          sudo apt-get update -qq && sudo apt-get install -y nodejs npm
        elif command -v dnf &>/dev/null; then
          sudo dnf install -y nodejs npm
        elif command -v pacman &>/dev/null; then
          sudo pacman -S --noconfirm nodejs npm
        else
          fail "Install Node.js 18+ manually: https://nodejs.org"
        fi
      fi
    else
      fail "curl not found. Install curl and Node.js 18+ manually."
    fi
  else
    fail "Unsupported OS. Install Node.js 18+ manually: https://nodejs.org"
  fi

  # Verify install worked
  if ! command -v node &>/dev/null; then
    fail "Node.js install completed but 'node' not found. Open a new terminal and re-run."
  fi
  info "Node.js installed: $(node -v)"
fi

# ─── 2. npm check ─────────────────────────────────────────
if ! command -v npm &>/dev/null; then
  fail "npm not found. Reinstall Node.js: https://nodejs.org"
fi
info "npm found: $(npm -v)"

# ─── 3. Install Claude Code ───────────────────────────────
# Check if npm global installs need sudo
NPM_PREFIX=$(npm config get prefix 2>/dev/null)
NEEDS_SUDO=false
if [ -n "$NPM_PREFIX" ] && [ ! -w "$NPM_PREFIX/lib" ] 2>/dev/null; then
  NEEDS_SUDO=true
fi

if command -v claude &>/dev/null; then
  info "Claude Code already installed, updating..."
  if $NEEDS_SUDO; then
    sudo npm update -g @anthropic-ai/claude-code
  else
    npm update -g @anthropic-ai/claude-code
  fi
else
  info "Installing Claude Code..."
  if $NEEDS_SUDO; then
    sudo npm install -g @anthropic-ai/claude-code
  else
    npm install -g @anthropic-ai/claude-code
  fi
fi

# Make sure claude is in PATH
if ! command -v claude &>/dev/null; then
  # Try common npm global bin locations
  for p in "$NPM_PREFIX/bin" "$HOME/.local/bin" "$HOME/.npm-global/bin"; do
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

# ─── 4. Claude config directory ────────────────────────────
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# ─── 5. CLAUDE.md preferences (no secrets) ────────────────
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

# ─── Done ──────────────────────────────────────────────────
echo ""
echo "======================================="
info "SETUP COMPLETE!"
echo ""
echo "  Next: Run 'claude' to log in (OAuth)"
echo "  No API keys or secrets stored."
echo "======================================="
echo ""
