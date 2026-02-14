---
name: flutter-skill
description: "AI-powered E2E testing for any app. Launch apps, tap buttons, enter text, scroll, take screenshots — all with natural language. Supports Flutter, React Native, Electron, Tauri, Android, iOS, KMP, .NET MAUI."
homepage: https://github.com/ai-dashboad/flutter-skill
metadata:
  {
    "openclaw":
      {
        "emoji": "🧪",
        "requires": { "bins": ["flutter-skill"] },
        "install":
          [
            {
              "id": "npm",
              "kind": "npm",
              "package": "flutter-skill",
              "global": true,
              "bins": ["flutter-skill"],
              "label": "Install flutter-skill (npm)",
            },
            {
              "id": "brew",
              "kind": "brew",
              "formula": "ai-dashboad/flutter-skill/flutter-skill",
              "bins": ["flutter-skill"],
              "label": "Install flutter-skill (Homebrew)",
            },
          ],
      },
  }
---

# Flutter Skill — AI E2E Testing

Give your AI agent eyes and hands inside any running app. No test code needed.

## Quick Start

### 1. Setup your app (one-time)

```bash
flutter-skill init
```

Auto-detects project type (Flutter/iOS/Android/React Native/Web) and patches your app.

### 2. Launch and connect

```bash
flutter-skill launch .
```

### 3. Test with natural language

Just tell the agent what to test:

> "Test the login flow — enter admin and password123, tap Login, verify Dashboard appears"

The agent will automatically screenshot, find elements, tap, type, scroll, and verify.

## MCP Configuration

Add to your MCP config (already done if using OpenClaw):

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

### Core Actions
- `screenshot` — Capture current screen (always start with this)
- `tap(selector)` — Tap a button, link, or element
- `enter_text(selector, text)` — Type into a text field
- `scroll(direction)` — Scroll up/down/left/right
- `swipe(startX, startY, endX, endY)` — Swipe gesture
- `long_press(selector)` — Long press an element
- `go_back` — Navigate back

### Inspection
- `get_elements` — List all interactive elements on screen
- `get_element_properties(selector)` — Get details of a specific element
- `wait_for_element(selector)` — Wait for element to appear

### Text
- `set_text(selector, text)` — Replace text in a field
- `clear_text(selector)` — Clear a text field
- `get_text(selector)` — Read text content

### App Control
- `get_logs` — Read app logs
- `clear_logs` — Clear log buffer

## Testing Workflow

Best practice for E2E testing:

```
1. screenshot()          → see what's on screen
2. get_elements()        → discover interactive elements
3. tap/enter_text/scroll → interact
4. screenshot()          → verify result
5. repeat
```

## Selector Types

Elements can be targeted by:
- **Key**: `key:login_button` (most reliable)
- **Text**: `text:Login` or just `Login`
- **Type**: `type:TextField`

## Example Prompts

Simple test:
> "Tap every tab in the bottom bar and take a screenshot of each page"

Comprehensive test:
> "Explore this app completely. Test all screens, buttons, forms, and navigation. Report any bugs."

Edge case testing:
> "Test the search feature: try empty search, special characters, very long input, and valid queries"

Form testing:
> "Fill the registration form with test data, submit it, and verify the success message"

## Supported Platforms (8)

| Platform | Test Score |
|----------|-----------|
| Flutter iOS/Android/Web | 21/21 |
| React Native | 24/24 |
| Electron | 24/24 |
| Android Native | 24/24 |
| Tauri | 23/24 |
| .NET MAUI | 23/24 |
| KMP Desktop | 22/22 |

**Total: 181/183 (99% pass rate)**

## Tips

- Always `screenshot()` before and after actions to verify state
- Use `wait_for_element()` after navigation — apps need time to transition
- Use `get_elements()` when unsure what's on screen
- Prefer `key:` selectors over text when available
- For flaky tests, add a brief pause between rapid actions
