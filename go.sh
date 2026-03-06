#!/usr/bin/env bash
# Claude Code Quick Setup — Mac/Linux
# Run: curl -fsSL <GIST_RAW_URL> | bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
fail()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "═══════════════════════════════════════"
echo "   Claude Code — Quick Setup"
echo "═══════════════════════════════════════"
echo ""

# 1. Check Node.js
if command -v node &>/dev/null; then
  NODE_VER=$(node -v)
  info "Node.js found: $NODE_VER"
  # Claude Code needs Node 18+
  MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [ "$MAJOR" -lt 18 ]; then
    fail "Node.js 18+ required (you have $NODE_VER). Update: https://nodejs.org"
  fi
else
  warn "Node.js not found. Installing..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &>/dev/null; then
      brew install node
    else
      fail "Install Node.js 18+: https://nodejs.org or install Homebrew first"
    fi
  elif [[ "$OSTYPE" == "linux"* ]]; then
    if command -v apt-get &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y nodejs
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm nodejs npm
    else
      fail "Install Node.js 18+ manually: https://nodejs.org"
    fi
  fi
  info "Node.js installed: $(node -v)"
fi

# 2. Check npm
if ! command -v npm &>/dev/null; then
  fail "npm not found. Reinstall Node.js: https://nodejs.org"
fi
info "npm found: $(npm -v)"

# 3. Install Claude Code
if command -v claude &>/dev/null; then
  info "Claude Code already installed, updating..."
  npm update -g @anthropic-ai/claude-code
else
  info "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
fi
info "Claude Code installed: $(claude --version 2>/dev/null || echo 'installed')"

# 4. Create config directory
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# 5. Apply preferred settings (no secrets — just preferences)
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
  info "Created default CLAUDE.md preferences"
else
  info "CLAUDE.md already exists, keeping yours"
fi

echo ""
echo "═══════════════════════════════════════"
info "Setup complete!"
echo ""
echo "  Next step: Run 'claude' to log in"
echo "  (Opens browser for secure OAuth)"
echo ""
echo "  No API keys stored locally."
echo "  Authentication is via Anthropic OAuth."
echo "═══════════════════════════════════════"
echo ""
