# Flutter Skill - VSCode Extension

Control Flutter apps with AI agents - inspect UI, perform gestures, take screenshots.

## Features

- **Launch App**: Start Flutter app with Flutter Skill integration
- **Inspect UI**: View interactive elements and widget tree
- **Take Screenshot**: Capture app screenshots
- **MCP Server**: Start MCP server for AI agent integration

## Installation

### From VSIX (Local)

```bash
cd vscode-extension
npm install
npm run compile
npm run package
# Install the .vsix file in VSCode
```

### From Marketplace

Search for "Flutter Skill" in VSCode Extensions.

## Requirements

- Flutter SDK
- Dart SDK
- flutter_skill package: `dart pub global activate flutter_skill`

## Commands

| Command | Description |
|---------|-------------|
| `Flutter Skill: Launch App` | Launch Flutter app with auto-setup |
| `Flutter Skill: Inspect UI` | Show interactive elements |
| `Flutter Skill: Take Screenshot` | Capture screenshot |
| `Flutter Skill: Start MCP Server` | Start MCP server for AI agents |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `flutter-skill.dartPath` | `dart` | Path to Dart executable |
| `flutter-skill.flutterPath` | `flutter` | Path to Flutter executable |
| `flutter-skill.autoConnect` | `true` | Auto-connect when app starts |

## MCP Integration

For Cursor/Windsurf, use this config:

```json
{
  "flutter-skill": {
    "command": "npx",
    "args": ["flutter-skill-mcp"]
  }
}
```

## Publishing

```bash
npm install
npm run compile
npm run package  # Creates .vsix
npm run publish  # Publish to marketplace (requires token)
```

## Links

- [GitHub](https://github.com/ai-dashboad/flutter-skill)
- [pub.dev](https://pub.dev/packages/flutter_skill)
- [npm](https://www.npmjs.com/package/flutter-skill-mcp)
