---
name: flutter-skill-testing
version: 0.7.6
category: testing
priority: high
auto_activate: true
tags: [flutter, e2e, testing, ai, mcp, ios, android, react-native, electron, tauri]
description: AI-powered E2E testing for any app. Test 8 platforms with natural language — no test code needed.
---

# Flutter Skill — AI E2E Testing

> Give your AI agent eyes and hands inside any running app.

## Description

This skill teaches you how to use flutter-skill to perform end-to-end testing on running applications across 8 platforms: Flutter, iOS, Android, Web, Electron, Tauri, KMP Desktop, React Native, and .NET MAUI.

flutter-skill is an MCP server that connects AI agents to running apps via a bridge protocol. The agent can see screenshots, tap elements, enter text, scroll, navigate, and verify UI state — all without writing test code.

## Install

```bash
npm install -g flutter-skill
```

## MCP Configuration

Add to your MCP config (Claude Desktop, Cursor, Windsurf, etc.):

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `screenshot` | Capture current screen state |
| `tap` | Tap an element by key or text |
| `enter_text` | Type text into a field |
| `scroll` | Scroll in any direction |
| `go_back` | Navigate back |
| `get_element_properties` | Inspect element details |
| `wait_for_element` | Wait for element to appear |
| `get_elements` | List all interactive elements |
| `swipe` | Swipe gesture |
| `long_press` | Long press an element |
| `drag` | Drag from one point to another |
| `set_text` | Replace text in a field |
| `clear_text` | Clear a text field |

## How to Test an App

### Step 1: Launch the app
```bash
flutter-skill launch /path/to/your/app
```

### Step 2: Ask your AI agent to test it
Just describe what to test in natural language:

> "Test the login flow — enter test@example.com and password123, tap Login, verify Dashboard appears"

The agent will:
1. `screenshot()` → see the current screen
2. `enter_text("email", "test@example.com")` → type email
3. `enter_text("password", "password123")` → type password
4. `tap("Login")` → tap the button
5. `wait_for_element("Dashboard")` → verify navigation
6. `screenshot()` → confirm final state

### Step 3: Complex testing
For comprehensive testing, describe the full flow:

> "Explore every screen of this app. Test all buttons, forms, navigation, and edge cases. Report any bugs."

The agent will systematically navigate every screen, interact with every element, and report findings.

## Best Practices

1. **Always start with `screenshot()`** — see what's on screen before acting
2. **Use `wait_for_element()` after navigation** — apps need time to transition
3. **Use `get_elements()` when unsure** — discover available interactive elements
4. **Take screenshots after actions** — verify the action had the expected effect
5. **Use element keys when available** — more reliable than text matching

## Supported Platforms

| Platform | SDK Setup |
|----------|-----------|
| Flutter | `flutter pub add flutter_skill` + wrap with `FlutterSkillBinding` |
| iOS (Swift) | Add `FlutterSkillSDK` SPM package |
| Android (Kotlin) | Add `flutter-skill-android` dependency |
| React Native | `npm install flutter-skill-react-native` |
| Electron | `npm install flutter-skill-electron` |
| Tauri | `cargo add flutter-skill-tauri` |
| KMP Desktop | Add Gradle dependency |
| .NET MAUI | Add NuGet package |

## Links

- [GitHub](https://github.com/ai-dashboad/flutter-skill)
- [Documentation](https://github.com/ai-dashboad/flutter-skill/blob/main/docs/USAGE_GUIDE.md)
- [npm](https://www.npmjs.com/package/flutter-skill)
- [Demo Video](https://github.com/user-attachments/assets/d4617c73-043f-424c-9a9a-1a61d4c2d3c6)
