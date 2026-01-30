# flutter-skill-mcp

> MCP Server for Flutter app automation - Give your AI Agent eyes and hands inside your Flutter app

[![npm version](https://badge.fury.io/js/flutter-skill-mcp.svg)](https://www.npmjs.com/package/flutter-skill-mcp)
[![pub version](https://img.shields.io/pub/v/flutter_skill.svg)](https://pub.dev/packages/flutter_skill)

## Installation

```bash
npm install -g flutter-skill-mcp
# or use directly with npx
npx flutter-skill-mcp
```

**Prerequisites**: [Flutter SDK](https://docs.flutter.dev/get-started/install) or [Dart SDK](https://dart.dev/get-dart)

## MCP Configuration

Add to your MCP config (Cursor, Windsurf, Claude Desktop):

```json
{
  "flutter-skill": {
    "command": "npx",
    "args": ["flutter-skill-mcp"]
  }
}
```

Or if installed globally:

```json
{
  "flutter-skill": {
    "command": "flutter-skill-mcp"
  }
}
```

## Features

- **UI Inspection**: Widget tree, text content, element properties
- **Interactions**: Tap, double tap, long press, swipe, drag, scroll
- **State Validation**: Text values, checkbox state, wait for elements
- **Screenshots**: Full app or specific elements
- **Navigation**: Routes, go back, navigation stack
- **Debug**: Logs, errors, performance metrics

## 25+ MCP Tools

| Category | Tools |
|----------|-------|
| Connection | `connect_app`, `launch_app` |
| UI Inspection | `inspect`, `get_widget_tree`, `get_widget_properties`, `get_text_content`, `find_by_type` |
| Interactions | `tap`, `double_tap`, `long_press`, `swipe`, `drag`, `scroll_to`, `enter_text` |
| State | `get_text_value`, `get_checkbox_state`, `get_slider_value`, `wait_for_element`, `wait_for_gone` |
| Screenshot | `screenshot`, `screenshot_element` |
| Navigation | `get_current_route`, `go_back`, `get_navigation_stack` |
| Debug | `get_logs`, `get_errors`, `get_performance`, `clear_logs` |
| Dev | `hot_reload`, `pub_search` |

## Links

- [GitHub](https://github.com/ai-dashboad/flutter-skill)
- [pub.dev](https://pub.dev/packages/flutter_skill)
- [Documentation](https://github.com/ai-dashboad/flutter-skill#readme)

## License

MIT
