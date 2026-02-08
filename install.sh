#!/bin/bash
# Flutter Skill One-Click Installation Script
# Supports macOS and Linux

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

printf '%b\n' "${BLUE}Flutter Skill One-Click Installation${NC}"
echo ""

# Detect operating system
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

if [ "$MACHINE" = "UNKNOWN:${OS}" ]; then
    printf '%b\n' "${RED}[X] Unsupported operating system: ${OS}${NC}"
    exit 1
fi

# ========== Helper Functions ==========

# Install tool priority rules directly (no dependency on CLI)
install_tool_priority_rules() {
    local PROMPTS_DIR="$HOME/.claude/prompts"
    local TARGET_FILE="$PROMPTS_DIR/flutter-tool-priority.md"

    if [ -f "$TARGET_FILE" ]; then
        printf '%b\n' "  ${GREEN}[OK] Tool priority rules already installed${NC}"
        return 0
    fi

    mkdir -p "$PROMPTS_DIR"

    # Try downloading from GitHub
    local URL="https://raw.githubusercontent.com/ai-dashboad/flutter-skill/main/docs/prompts/tool-priority.md"
    if command -v curl &> /dev/null; then
        if curl -fsSL "$URL" -o "$TARGET_FILE" 2>/dev/null; then
            printf '%b\n' "  ${GREEN}[OK] Tool priority rules installed${NC}"
            return 0
        fi
    elif command -v wget &> /dev/null; then
        if wget -qO "$TARGET_FILE" "$URL" 2>/dev/null; then
            printf '%b\n' "  ${GREEN}[OK] Tool priority rules installed${NC}"
            return 0
        fi
    fi

    # Fallback: try using the CLI if available
    if command -v flutter-skill &> /dev/null; then
        flutter-skill setup --silent 2>/dev/null && printf '%b\n' "  ${GREEN}[OK] Tool priority rules installed${NC}" && return 0
    elif command -v flutter-skill-mcp &> /dev/null; then
        flutter-skill-mcp setup --silent 2>/dev/null && printf '%b\n' "  ${GREEN}[OK] Tool priority rules installed${NC}" && return 0
    fi

    printf '%b\n' "  ${YELLOW}[!] Could not install tool priority rules automatically${NC}"
    echo "      Run manually: flutter-skill setup"
    return 0
}

# Add flutter-skill MCP entry to a JSON settings file using python3
# Usage: add_mcp_to_json <file_path> <command_name>
add_mcp_to_json() {
    local FILE_PATH="$1"
    local CMD_NAME="$2"

    python3 -c "
import json, sys, os

file_path = sys.argv[1]
cmd = sys.argv[2]

entry = {'command': cmd, 'args': ['server']}

if os.path.exists(file_path):
    with open(file_path) as f:
        try:
            data = json.load(f)
        except:
            data = {}
else:
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    data = {}

if 'mcpServers' not in data:
    data['mcpServers'] = {}

data['mcpServers']['flutter-skill'] = entry

with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$FILE_PATH" "$CMD_NAME" 2>/dev/null
}

# Configure IDE MCP settings (auto-write)
configure_ide() {
    local CMD_NAME="$1"  # flutter-skill or flutter-skill-mcp

    echo ""
    printf '%b\n' "${BLUE}Configuring IDE integration...${NC}"

    # Claude Code
    local CLAUDE_DIR="$HOME/.claude"
    local CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
    if [ -d "$CLAUDE_DIR" ]; then
        if [ -f "$CLAUDE_SETTINGS" ] && grep -q "flutter-skill\|flutter_skill" "$CLAUDE_SETTINGS" 2>/dev/null; then
            printf '%b\n' "  ${GREEN}[OK] Claude Code: already configured${NC}"
        else
            if command -v python3 &> /dev/null; then
                add_mcp_to_json "$CLAUDE_SETTINGS" "$CMD_NAME"
                printf '%b\n' "  ${GREEN}[OK] Claude Code: configured${NC}"
            else
                printf '%b\n' "  ${YELLOW}[!] Claude Code: python3 not found, manual config needed${NC}"
                echo "      Add to $CLAUDE_SETTINGS:"
                echo "      {\"mcpServers\":{\"flutter-skill\":{\"command\":\"$CMD_NAME\",\"args\":[\"server\"]}}}"
            fi
        fi
    fi

    # Cursor
    local CURSOR_DIR="$HOME/.cursor"
    local CURSOR_CONFIG="$CURSOR_DIR/mcp.json"
    if [ -d "$CURSOR_DIR" ]; then
        if [ -f "$CURSOR_CONFIG" ] && grep -q "flutter-skill\|flutter_skill" "$CURSOR_CONFIG" 2>/dev/null; then
            printf '%b\n' "  ${GREEN}[OK] Cursor: already configured${NC}"
        else
            if command -v python3 &> /dev/null; then
                add_mcp_to_json "$CURSOR_CONFIG" "$CMD_NAME"
                printf '%b\n' "  ${GREEN}[OK] Cursor: configured${NC}"
            else
                printf '%b\n' "  ${YELLOW}[!] Cursor: python3 not found, manual config needed${NC}"
                echo "      Add to $CURSOR_CONFIG:"
                echo "      {\"mcpServers\":{\"flutter-skill\":{\"command\":\"$CMD_NAME\",\"args\":[\"server\"]}}}"
            fi
        fi
    fi
}

# Add to PATH for detected shells (zsh, bash, fish)
add_to_path() {
    local BIN_DIR="$1"
    local CONFIGS_UPDATED=0

    # zsh
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo '# Flutter Skill' >> "$HOME/.zshrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
            printf '%b\n' "  ${GREEN}[OK] Added to PATH: ~/.zshrc${NC}"
            CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
        fi
    fi

    # bash
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo '# Flutter Skill' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            printf '%b\n' "  ${GREEN}[OK] Added to PATH: ~/.bashrc${NC}"
            CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
        fi
    elif [ -f "$HOME/.bash_profile" ]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bash_profile" 2>/dev/null; then
            echo "" >> "$HOME/.bash_profile"
            echo '# Flutter Skill' >> "$HOME/.bash_profile"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bash_profile"
            printf '%b\n' "  ${GREEN}[OK] Added to PATH: ~/.bash_profile${NC}"
            CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
        fi
    fi

    # fish
    if [ -d "$HOME/.config/fish" ]; then
        local FISH_CONFIG="$HOME/.config/fish/config.fish"
        if [ ! -f "$FISH_CONFIG" ] || ! grep -q 'flutter-skill\|flutter_skill' "$FISH_CONFIG" 2>/dev/null; then
            mkdir -p "$HOME/.config/fish"
            echo "" >> "$FISH_CONFIG"
            echo '# Flutter Skill' >> "$FISH_CONFIG"
            echo "fish_add_path $BIN_DIR" >> "$FISH_CONFIG"
            printf '%b\n' "  ${GREEN}[OK] Added to PATH: ~/.config/fish/config.fish${NC}"
            CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
        fi
    fi

    if [ $CONFIGS_UPDATED -eq 0 ]; then
        printf '%b\n' "  ${YELLOW}[!] Could not detect shell config file${NC}"
        echo "      Add this to your shell config:"
        echo "        export PATH=\"$BIN_DIR:\$PATH\""
    fi
}

# Verify installation works
verify_install() {
    local CMD_NAME="$1"
    echo ""
    printf '%b\n' "${BLUE}Verifying installation...${NC}"

    if command -v "$CMD_NAME" &> /dev/null; then
        local VERSION_OUTPUT
        VERSION_OUTPUT=$("$CMD_NAME" --version 2>/dev/null) || true
        # Only show version if it looks like a version number
        if echo "$VERSION_OUTPUT" | grep -qE '^[0-9]+\.[0-9]+'; then
            printf '%b\n' "  ${GREEN}[OK] $CMD_NAME v${VERSION_OUTPUT}${NC}"
        else
            printf '%b\n' "  ${GREEN}[OK] $CMD_NAME installed${NC}"
        fi
        return 0
    else
        printf '%b\n' "  ${YELLOW}[!] $CMD_NAME not found in PATH${NC}"
        echo "      You may need to restart your terminal"
        return 1
    fi
}

# Show post-install summary
show_summary() {
    local CMD_NAME="$1"
    echo ""
    printf '%b\n' "${GREEN}============================================${NC}"
    printf '%b\n' "${GREEN}  Installation complete!${NC}"
    printf '%b\n' "${GREEN}============================================${NC}"
    echo ""
    echo "  Quick Start:"
    echo "    1. Launch your Flutter app:"
    printf '%b\n' "       ${CYAN}$CMD_NAME launch /path/to/flutter/app${NC}"
    echo ""
    echo "    2. Or configure as MCP server in your IDE:"
    printf '%b\n' "       ${CYAN}{ \"command\": \"$CMD_NAME\", \"args\": [\"server\"] }${NC}"
    echo ""
    echo "    3. Check environment health:"
    printf '%b\n' "       ${CYAN}$CMD_NAME doctor${NC}"
    echo ""
    echo "  Docs: https://pub.dev/packages/flutter_skill"
    echo ""
}

# ========== Installation Methods ==========

printf '%b\n' "${YELLOW}Detecting best installation method...${NC}"
echo ""

# Method 1: npm (Recommended - pre-compiled binary, fastest startup)
if command -v npm &> /dev/null; then
    printf '%b\n' "${GREEN}[OK] npm detected, installing via npm (recommended)${NC}"
    echo ""

    if command -v flutter-skill &> /dev/null || command -v flutter-skill-mcp &> /dev/null; then
        printf '%b\n' "${YELLOW}Updating flutter-skill to latest version...${NC}"
    fi
    echo "Running: npm install -g flutter-skill-mcp"
    npm install -g flutter-skill-mcp

    CMD="flutter-skill-mcp"
    if command -v flutter-skill &> /dev/null; then
        CMD="flutter-skill"
    fi

    verify_install "$CMD"

    echo ""
    printf '%b\n' "${BLUE}Setting up tool priority rules...${NC}"
    install_tool_priority_rules

    configure_ide "$CMD"
    show_summary "$CMD"
    exit 0
fi

# Method 2: Homebrew (macOS/Linux)
if [ "$MACHINE" = "Mac" ] && command -v brew &> /dev/null; then
    printf '%b\n' "${GREEN}[OK] Homebrew detected, installing via brew${NC}"
    echo ""
    echo "Running: brew tap ai-dashboad/flutter-skill && brew install flutter-skill"
    brew tap ai-dashboad/flutter-skill
    brew install flutter-skill

    verify_install "flutter-skill"

    echo ""
    printf '%b\n' "${BLUE}Setting up tool priority rules...${NC}"
    install_tool_priority_rules

    configure_ide "flutter-skill"
    show_summary "flutter-skill"
    exit 0
fi

# Method 3: Install from source (requires Dart/Flutter)
if command -v dart &> /dev/null || command -v flutter &> /dev/null; then
    printf '%b\n' "${YELLOW}[!] npm or Homebrew not detected${NC}"
    printf '%b\n' "${YELLOW}Installing from source using Dart (requires Flutter SDK)${NC}"
    echo ""

    if ! command -v flutter &> /dev/null; then
        printf '%b\n' "${RED}[X] Error: Flutter SDK not found${NC}"
        echo ""
        echo "Please install Flutter first: https://flutter.dev/docs/get-started/install"
        echo ""
        echo "Or use one of the following methods:"
        echo "  npm install -g flutter-skill-mcp  (recommended)"
        echo "  brew install flutter-skill        (macOS)"
        exit 1
    fi

    INSTALL_DIR="$HOME/.flutter-skill-src"

    if [ ! -d "$INSTALL_DIR" ]; then
        echo "Cloning repository to $INSTALL_DIR ..."
        git clone https://github.com/ai-dashboad/flutter-skill.git "$INSTALL_DIR"
    else
        echo "Updating source code..."
        cd "$INSTALL_DIR"
        git pull origin main
    fi

    cd "$INSTALL_DIR"

    echo "Installing dependencies..."
    flutter pub get

    echo "Creating executable..."
    mkdir -p "$HOME/bin"

    cat > "$HOME/bin/flutter-skill" << 'WRAPPER_EOF'
#!/bin/bash
FLUTTER_SKILL_DIR="$HOME/.flutter-skill-src"
cd "$FLUTTER_SKILL_DIR"
dart run bin/flutter_skill.dart "$@"
WRAPPER_EOF

    chmod +x "$HOME/bin/flutter-skill"

    echo ""
    printf '%b\n' "${BLUE}Configuring PATH...${NC}"
    add_to_path "$HOME/bin"

    verify_install "flutter-skill" || printf '%b\n' "  ${YELLOW}Run: source ~/.zshrc (or restart terminal)${NC}"

    echo ""
    printf '%b\n' "${BLUE}Setting up tool priority rules...${NC}"
    install_tool_priority_rules

    configure_ide "flutter-skill"
    show_summary "flutter-skill"
    exit 0
fi

# No installation method found
printf '%b\n' "${RED}[X] Error: No available installation method found${NC}"
echo ""
echo "Please install one of the following tools:"
echo "  1. npm  (recommended) - https://nodejs.org/"
echo "  2. Homebrew (macOS) - https://brew.sh/"
echo "  3. Flutter SDK - https://flutter.dev/"
echo ""
echo "Then run this script again"
exit 1
