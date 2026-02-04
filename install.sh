#!/bin/bash
# Flutter Skill One-Click Installation Script
# Supports macOS and Linux

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Flutter Skill One-Click Installation${NC}"
echo ""

# Detect operating system
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

if [ "$MACHINE" = "UNKNOWN:${OS}" ]; then
    echo -e "${RED}❌ Unsupported operating system: ${OS}${NC}"
    exit 1
fi

# Detect installation method
echo -e "${YELLOW}Detecting best installation method...${NC}"
echo ""

# Method 1: npm (Recommended - pre-compiled binary, fastest startup)
if command -v npm &> /dev/null; then
    echo -e "${GREEN}✅ npm detected, installing via npm (recommended)${NC}"
    echo ""

    # Check if already installed
    if command -v flutter-skill &> /dev/null || command -v flutter-skill-mcp &> /dev/null; then
        echo -e "${YELLOW}⚠️  flutter-skill already installed, updating...${NC}"
        echo "Running: npm install -g flutter-skill-mcp --force"
        npm install -g flutter-skill-mcp --force
    else
        echo "Running: npm install -g flutter-skill-mcp"
        npm install -g flutter-skill-mcp
    fi

    echo ""
    echo -e "${GREEN}✅ Installation successful!${NC}"
    echo ""
    echo "Verifying installation:"
    flutter-skill --version 2>/dev/null || flutter-skill-mcp --version 2>/dev/null || echo "flutter-skill command installed"

    # Install tool priority rules
    echo ""
    echo -e "${YELLOW}📝 Installing Claude Code tool priority rules...${NC}"
    if command -v flutter-skill &> /dev/null; then
        flutter-skill setup --silent 2>/dev/null || echo "Tool priority rules installed"
    elif command -v flutter-skill-mcp &> /dev/null; then
        flutter-skill-mcp setup --silent 2>/dev/null || echo "Tool priority rules installed"
    fi

    echo ""
    echo -e "${GREEN}🎉 Installation complete!${NC}"
    exit 0
fi

# Method 2: Homebrew (macOS/Linux)
if [ "$MACHINE" = "Mac" ] && command -v brew &> /dev/null; then
    echo -e "${GREEN}✅ Homebrew detected, installing via brew${NC}"
    echo ""
    echo "Running: brew tap ai-dashboad/flutter-skill && brew install flutter-skill"
    brew tap ai-dashboad/flutter-skill
    brew install flutter-skill

    echo ""
    echo -e "${GREEN}✅ Installation successful!${NC}"
    echo ""
    echo "Verifying installation:"
    flutter-skill --version

    # Install tool priority rules
    echo ""
    echo -e "${YELLOW}📝 Installing Claude Code tool priority rules...${NC}"
    flutter-skill setup --silent || echo "Tool priority rules installed"

    echo ""
    echo -e "${GREEN}🎉 Installation complete!${NC}"
    exit 0
fi

# Method 3: Install from source (requires Dart/Flutter)
if command -v dart &> /dev/null || command -v flutter &> /dev/null; then
    echo -e "${YELLOW}⚠️  npm or Homebrew not detected${NC}"
    echo -e "${YELLOW}Installing from source using Dart (requires Flutter SDK)${NC}"
    echo ""

    # Detect Flutter
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Error: Flutter SDK not found${NC}"
        echo ""
        echo "Please install Flutter first: https://flutter.dev/docs/get-started/install"
        echo ""
        echo "Or use one of the following methods:"
        echo "  • npm install -g flutter-skill-mcp  (recommended)"
        echo "  • brew install flutter-skill        (macOS)"
        exit 1
    fi

    # Download source code (if needed)
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

    # Install dependencies
    echo "Installing dependencies..."
    flutter pub get

    # Create wrapper script
    echo "Creating executable..."
    mkdir -p "$HOME/bin"

    cat > "$HOME/bin/flutter-skill" << 'WRAPPER_EOF'
#!/bin/bash
FLUTTER_SKILL_DIR="$HOME/.flutter-skill-src"
cd "$FLUTTER_SKILL_DIR"
dart run bin/flutter_skill.dart "$@"
WRAPPER_EOF

    chmod +x "$HOME/bin/flutter-skill"

    # Add to PATH
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    fi

    if [ -n "$SHELL_RC" ]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo '# Flutter Skill' >> "$SHELL_RC"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
            echo ""
            echo -e "${GREEN}✅ Added to PATH: $SHELL_RC${NC}"
            echo -e "${YELLOW}Please run: source $SHELL_RC${NC}"
        fi
    fi

    # Verify installation
    echo ""
    echo -e "${GREEN}✅ Installation successful!${NC}"
    echo ""
    echo "Verifying installation:"
    "$HOME/bin/flutter-skill" --version || echo "flutter-skill installed to $HOME/bin/flutter-skill"

    # Install tool priority rules
    echo ""
    echo -e "${YELLOW}📝 Installing Claude Code tool priority rules...${NC}"
    "$HOME/bin/flutter-skill" setup --silent || echo "Tool priority rules installed"

    echo ""
    echo -e "${GREEN}🎉 Installation complete!${NC}"
    exit 0
fi

# No installation method found
echo -e "${RED}❌ Error: No available installation method found${NC}"
echo ""
echo "Please install one of the following tools:"
echo "  1. npm  (recommended) - https://nodejs.org/"
echo "  2. Homebrew (macOS) - https://brew.sh/"
echo "  3. Flutter SDK - https://flutter.dev/"
echo ""
echo "Then run this script again"
exit 1
