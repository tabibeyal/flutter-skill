# Flutter Skill UI/UX 设计指南

## 1. 设计原则

### 核心理念
- **引导式** - 新手能快速上手，专家能高效操作
- **状态清晰** - 任何时候都能看到当前状态
- **错误友好** - 错误提示包含解决方案
- **渐进式** - 高级功能不干扰基础使用

### VSCode 插件设计准则
- 遵循 VSCode 视觉语言（Codicons, 间距, 配色）
- 使用 VSCode Webview UI Toolkit 组件
- 支持浅色/深色主题
- 快捷键友好

---

## 2. 界面结构重新设计

### 2.1 侧边栏（Primary Sidebar）

```
┌─────────────────────────────────────┐
│ 🎯 Flutter Skill               [⚙️][?] │
├─────────────────────────────────────┤
│                                     │
│ ╔═══ Connection Status ═══╗        │
│ ║  🟢 Connected                    ║
│ ║  📱 iPhone 16 Pro                ║
│ ║  ⚡ VM Service: :50000           ║
│ ║  [Disconnect] [Refresh]          ║
│ ╚══════════════════════════════════╝│
│                                     │
│ ┌─── Quick Actions ────────────┐   │
│ │ [▶️ Launch App     ]          │   │
│ │ [🔍 Inspect UI     ]          │   │
│ │ [📸 Screenshot     ]          │   │
│ │ [🔄 Hot Reload     ]          │   │
│ └──────────────────────────────┘   │
│                                     │
│ ┌─── Interactive Elements ─────┐   │
│ │ 📱 HomePage                   │   │
│ │   ├─ 🔘 login_button          │   │
│ │   ├─ 📝 email_field           │   │
│ │   └─ 📝 password_field        │   │
│ │ [Tap] [Input] [Inspect]       │   │
│ └──────────────────────────────┘   │
│                                     │
│ ┌─── Testing History ──────────┐   │
│ │ ✅ Login flow test (2m ago)  │   │
│ │ ✅ Screenshot capture         │   │
│ │ ❌ Form validation (5m ago)  │   │
│ │ [View All]                    │   │
│ └──────────────────────────────┘   │
│                                     │
│ ┌─── AI Editors ───────────────┐   │
│ │ ✅ Claude Code                │   │
│ │ ✅ Cursor                     │   │
│ │ ⚠️  Windsurf (Setup needed)  │   │
│ │ [Configure]                   │   │
│ └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 2.2 Webview 面板（详细视图）

**Inspector 视图:**
```
┌─────────────────────────────────────────────────┐
│ 🔍 UI Inspector                    [📸][🔄][✕] │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────── Screenshot ────────────┐         │
│  │                                   │         │
│  │     [App screenshot preview]      │         │
│  │     with element highlights       │         │
│  │                                   │         │
│  └───────────────────────────────────┘         │
│                                                 │
│  📋 Interactive Elements (12 found)             │
│  ┌───────────────────────────────────────────┐ │
│  │ ┌─ login_button ────────────────────────┐ │ │
│  │ │ Type: ElevatedButton                  │ │ │
│  │ │ Text: "Login"                         │ │ │
│  │ │ Position: (x: 156, y: 420)            │ │ │
│  │ │ Size: 120x48                          │ │ │
│  │ │ [Tap] [Highlight] [Properties]        │ │ │
│  │ └───────────────────────────────────────┘ │ │
│  │                                           │ │
│  │ ┌─ email_field ─────────────────────────┐ │ │
│  │ │ Type: TextField                       │ │ │
│  │ │ Hint: "Enter email"                   │ │ │
│  │ │ Value: "test@example.com"             │ │ │
│  │ │ [Input Text] [Clear] [Properties]     │ │ │
│  │ └───────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│  🎯 Quick Test Builder                          │
│  ┌─────────────────────────────────────────┐   │
│  │ 1. Tap "email_field"        [▶️][✕]     │   │
│  │ 2. Input "test@example.com" [▶️][✕]     │   │
│  │ 3. Tap "login_button"       [▶️][✕]     │   │
│  │ [+ Add Step] [▶️ Run All] [💾 Save]     │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### 2.3 状态栏（Status Bar）

```
┌──────────────────────────────────────────────────────┐
│ ... │ 🎯 Flutter: Connected (iPhone 16 Pro) │ ... │
└──────────────────────────────────────────────────────┘
        ↑ 点击打开 Quick Actions
```

---

## 3. 详细设计规范

### 3.1 颜色系统

```typescript
// 基于 VSCode 主题变量
const colors = {
  // 状态颜色
  success: 'var(--vscode-testing-iconPassed)',      // 绿色
  warning: 'var(--vscode-testing-iconQueued)',      // 黄色
  error: 'var(--vscode-testing-iconFailed)',        // 红色
  info: 'var(--vscode-charts-blue)',                // 蓝色

  // 功能颜色
  primary: 'var(--vscode-button-background)',
  secondary: 'var(--vscode-button-secondaryBackground)',

  // 边框和分隔
  border: 'var(--vscode-panel-border)',
  divider: 'var(--vscode-widget-border)',

  // 背景层次
  bg1: 'var(--vscode-sideBar-background)',
  bg2: 'var(--vscode-sideBarSectionHeader-background)',
  bg3: 'var(--vscode-input-background)',
}
```

### 3.2 图标系统

使用 Codicons + 自定义图标：

| 功能 | 图标 | Codicon |
|-----|------|---------|
| 连接状态 | 🟢🟡🔴 | `circle-filled` + color |
| 启动应用 | ▶️ | `debug-start` |
| 检查界面 | 🔍 | `search` |
| 截图 | 📸 | `device-camera` |
| 热重载 | 🔄 | `refresh` |
| Tap 操作 | 👆 | `hand` |
| 输入文本 | ⌨️ | `edit` |
| 历史记录 | 📜 | `history` |
| 设置 | ⚙️ | `settings-gear` |
| 帮助 | ❓ | `question` |

### 3.3 间距系统

```typescript
const spacing = {
  xxs: '2px',
  xs: '4px',
  sm: '8px',
  md: '12px',
  lg: '16px',
  xl: '24px',
  xxl: '32px',
}
```

### 3.4 组件规范

#### Button

```typescript
// Primary Action
<vscode-button appearance="primary">
  Launch App
</vscode-button>

// Secondary Action
<vscode-button appearance="secondary">
  Inspect
</vscode-button>

// Icon Button
<vscode-button appearance="icon" aria-label="Settings">
  <span class="codicon codicon-settings-gear"></span>
</vscode-button>
```

#### Card/Panel

```css
.card {
  background: var(--vscode-sideBarSectionHeader-background);
  border: 1px solid var(--vscode-panel-border);
  border-radius: 4px;
  padding: 12px;
  margin: 8px 0;
}

.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  margin-bottom: 8px;
}
```

#### Status Badge

```html
<span class="status-badge status-connected">
  <span class="codicon codicon-circle-filled"></span>
  Connected
</span>

<style>
.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
}

.status-connected {
  background: var(--vscode-testing-iconPassed);
  color: white;
}
</style>
```

---

## 4. 交互流程优化

### 4.1 首次使用流程（Onboarding）

```
┌─────────────────────────────────────┐
│ 👋 Welcome to Flutter Skill         │
├─────────────────────────────────────┤
│                                     │
│ Let's get you set up in 3 steps:   │
│                                     │
│ ✅ 1. Flutter SDK detected          │
│    └─ Flutter 3.24.0                │
│                                     │
│ ⏳ 2. Install tool priority rules   │
│    [Install Now] (Recommended)      │
│    This ensures Claude always uses  │
│    Flutter Skill for testing.       │
│                                     │
│ ⏳ 3. Configure AI editor            │
│    Which editor are you using?      │
│    ○ Claude Code                    │
│    ○ Cursor                         │
│    ○ Windsurf                       │
│    ○ Skip for now                   │
│                                     │
│ [Get Started]  [Show me a demo]     │
└─────────────────────────────────────┘
```

### 4.2 连接流程

```
┌─────────────────────────────────────┐
│ 📱 Connect to Flutter App           │
├─────────────────────────────────────┤
│                                     │
│ Choose how to connect:              │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ ▶️ Launch new app           │    │
│ │   Start your Flutter app    │    │
│ │   with auto-connect         │    │
│ │   [Select Device ▼]         │    │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 🔗 Connect to running app   │    │
│ │   Scan for running apps     │    │
│ │   [Scan Now]                │    │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 🔧 Manual connection        │    │
│ │   VM Service URI:           │    │
│ │   [ws://127.0.0.1:50000]    │    │
│ │   [Connect]                 │    │
│ └─────────────────────────────┘    │
│                                     │
│ [Cancel]                            │
└─────────────────────────────────────┘
```

### 4.3 错误处理流程

**Before (现在):**
```
❌ Connection error. Click for options.
```

**After (改进后):**
```
┌─────────────────────────────────────┐
│ ⚠️ Connection Failed                │
├─────────────────────────────────────┤
│                                     │
│ Problem:                            │
│ Could not connect to VM Service     │
│                                     │
│ Possible causes:                    │
│ • App is using DTD protocol         │
│ • App is not running                │
│ • Firewall blocking connection      │
│                                     │
│ Quick fixes:                        │
│ ┌─────────────────────────────┐    │
│ │ ⚡ Add --vm-service-port flag │   │
│ │   flutter run -d "iPhone"   │   │
│ │     --vm-service-port=50000 │   │
│ │   [Copy Command]            │   │
│ └─────────────────────────────┘    │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 🔄 Restart app with flag    │   │
│ │   [Restart Now]             │   │
│ └─────────────────────────────┘    │
│                                     │
│ [View Full Guide] [Report Issue]   │
└─────────────────────────────────────┘
```

---

## 5. 高级功能设计

### 5.1 Test Builder（可视化测试构建器）

```
┌───────────────────────────────────────────┐
│ 🧪 Test Builder                     [✕]   │
├───────────────────────────────────────────┤
│                                           │
│ Test Name: Login Flow Test               │
│ [───────────────────────────────]         │
│                                           │
│ Steps:                                    │
│ ┌───────────────────────────────────┐     │
│ │ 1. [👆 Tap] email_field           │     │
│ │    ↓                              │     │
│ │ 2. [⌨️ Input] "test@example.com"  │     │
│ │    ↓                              │     │
│ │ 3. [👆 Tap] password_field        │     │
│ │    ↓                              │     │
│ │ 4. [⌨️ Input] "password123"       │     │
│ │    ↓                              │     │
│ │ 5. [👆 Tap] login_button          │     │
│ │    ↓                              │     │
│ │ 6. [⏱️ Wait] for "Welcome" text   │     │
│ │    ↓                              │     │
│ │ 7. [📸 Screenshot] "success"      │     │
│ └───────────────────────────────────┘     │
│                                           │
│ [+ Add Step ▼]                            │
│   • Tap element                           │
│   • Input text                            │
│   • Wait for element                      │
│   • Screenshot                            │
│   • Assert text                           │
│                                           │
│ [▶️ Run Test] [💾 Save] [📋 Copy Code]    │
└───────────────────────────────────────────┘
```

### 5.2 Logs Viewer

```
┌─────────────────────────────────────────┐
│ 📜 Application Logs            [Clear]  │
├─────────────────────────────────────────┤
│ Filters: [All ▼] [Search...]            │
│ ┌─ ℹ️ Info  ─ ⚠️ Warn  ─ ❌ Error ──┐   │
│ │ 12:34:56 ℹ️  App started            │   │
│ │ 12:34:57 ℹ️  Navigated to /login    │   │
│ │ 12:34:58 ⚠️  Slow API response      │   │
│ │ 12:35:01 ❌ Auth failed: invalid    │   │
│ │              credentials            │   │
│ │              [View Stack Trace]     │   │
│ └────────────────────────────────────┘   │
│                                          │
│ [📥 Export] [🔍 Find] [⚙️ Settings]      │
└─────────────────────────────────────────┘
```

---

## 6. 配置界面优化

### Before (现在):
```
MCP Configuration

Add to your AI agent's MCP config:
{
  "mcpServers": {
    "flutter-skill": {
      ...
}
```

### After (改进后):
```
┌─────────────────────────────────────────┐
│ ⚙️ Settings                             │
├─────────────────────────────────────────┤
│                                         │
│ 🤖 AI Editor Integration                │
│ ┌───────────────────────────────────┐   │
│ │ Editor: [Claude Code       ▼]     │   │
│ │                                   │   │
│ │ ✅ Tool priority rules installed  │   │
│ │ ✅ MCP server configured          │   │
│ │                                   │   │
│ │ [Test Connection]                 │   │
│ └───────────────────────────────────┘   │
│                                         │
│ 📱 Default Device                       │
│ ┌───────────────────────────────────┐   │
│ │ [iPhone 16 Pro         ▼]         │   │
│ │ ☑️ Auto-launch on startup          │   │
│ └───────────────────────────────────┘   │
│                                         │
│ 🔧 Advanced Settings                    │
│ ┌───────────────────────────────────┐   │
│ │ VM Service Port: [50000]          │   │
│ │ Screenshot Quality: [─────●───]   │   │
│ │                       High        │   │
│ │ ☑️ Auto-reload on save             │   │
│ │ ☑️ Show notifications              │   │
│ └───────────────────────────────────┘   │
│                                         │
│ [Reset to Defaults]                     │
└─────────────────────────────────────────┘
```

---

## 7. 实现优先级

### Phase 1: 基础改进 (Week 1-2)
- ✅ 状态栏集成
- ✅ 连接状态卡片
- ✅ 错误提示优化
- ✅ 按钮分组和图标

### Phase 2: 核心功能 (Week 3-4)
- ✅ Inspector Webview
- ✅ Interactive Elements 列表
- ✅ Quick Actions 面板
- ✅ Onboarding 流程

### Phase 3: 高级功能 (Week 5-6)
- ✅ Test Builder
- ✅ Logs Viewer
- ✅ History Tracking
- ✅ 设置界面

### Phase 4: 打磨优化 (Week 7-8)
- ✅ 动画和过渡
- ✅ 快捷键支持
- ✅ 主题适配
- ✅ 性能优化

---

## 8. 技术栈建议

### VSCode Extension
```typescript
// extension.ts
import * as vscode from 'vscode';
import { FlutterSkillViewProvider } from './views/FlutterSkillViewProvider';

export function activate(context: vscode.ExtensionContext) {
  // 注册侧边栏
  const provider = new FlutterSkillViewProvider(context.extensionUri);

  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider(
      'flutter-skill.sidebarView',
      provider
    )
  );

  // 注册状态栏
  const statusBar = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Left,
    100
  );
  statusBar.text = "$(debug-disconnect) Flutter: Disconnected";
  statusBar.command = 'flutter-skill.showQuickActions';
  statusBar.show();
}
```

### Webview UI
```typescript
// Use VSCode Webview UI Toolkit
import {
  provideVSCodeDesignSystem,
  vsCodeButton,
  vsCodeTextField,
  vsCodePanels,
  vsCodeProgressRing,
} from "@vscode/webview-ui-toolkit";

provideVSCodeDesignSystem().register(
  vsCodeButton(),
  vsCodeTextField(),
  vsCodePanels(),
  vsCodeProgressRing()
);
```

### 状态管理
```typescript
// 使用 Zustand 或 Context API
interface FlutterSkillState {
  connectionStatus: 'connected' | 'disconnected' | 'connecting';
  device: Device | null;
  elements: UIElement[];
  testHistory: TestRun[];
}
```

---

## 9. 用户体验指标

### 成功标准
- ⏱️ 首次连接时间 < 10秒
- 🎯 新用户完成首次测试 < 2分钟
- 📊 错误自助解决率 > 80%
- ⭐ 用户满意度 > 4.5/5

### 测试检查清单
- [ ] 支持浅色/深色主题
- [ ] 键盘导航完整
- [ ] 屏幕阅读器兼容
- [ ] 动画可禁用
- [ ] 高对比度模式支持

---

## 10. 参考资源

### 设计系统
- [VSCode UX Guidelines](https://code.visualstudio.com/api/ux-guidelines/overview)
- [Codicons](https://microsoft.github.io/vscode-codicons/dist/codicon.html)
- [Webview UI Toolkit](https://github.com/microsoft/vscode-webview-ui-toolkit)

### 优秀示例
- GitLens
- Docker Extension
- Test Explorer UI
- Flutter DevTools (参考)

---

**最后更新**: 2026-02-01
**版本**: 1.0
**维护者**: Flutter Skill Team
