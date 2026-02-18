# IDE Setup Guides

## Claude Code / Claude Desktop

Add to `~/.claude/claude_desktop_config.json`:

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

Then ask Claude: *"Connect to my Flutter app and test the login flow"*

## Cursor

Add to `.cursor/mcp.json` in your project root:

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

Restart Cursor. The MCP tools appear in Cursor's tool panel.

## Windsurf

Add to `~/.codeium/windsurf/mcp_config.json`:

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

## Cline (VSCode Extension)

Open VSCode Settings → Extensions → Cline → MCP Servers:

```json
{
  "flutter-skill": {
    "command": "flutter-skill",
    "args": ["server"]
  }
}
```

## GitHub Copilot (VSCode)

Add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "flutter-skill": {
      "type": "stdio",
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

## OpenClaw

Already works out of the box via the `e2e-testing` skill. Or add manually:

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

## Verify Installation

After configuring, ask your AI:

> "List all flutter-skill tools"

You should see 237 tools. Then try:

> "Connect to https://example.com via CDP and take a screenshot"

If it works, you're all set! Try `page_summary` for the AI-native experience:

> "Get a page summary of the current page using flutter-skill"
