# Flutter Skill UI 改进实施路线图

## 📅 总体时间线: 8 周

---

## Week 1-2: 基础改进 🏗️

### 目标
快速优化现有界面，立即改善用户体验

### 任务清单

#### 1.1 状态栏集成
- [ ] 在 VSCode 状态栏添加 Flutter Skill 指示器
- [ ] 显示连接状态（已连接/未连接/连接中）
- [ ] 点击状态栏打开快捷操作
- [ ] 添加设备名称显示

**文件**: `vscode-extension/src/statusBar.ts`

```typescript
export class FlutterSkillStatusBar {
  private statusBarItem: vscode.StatusBarItem;

  constructor() {
    this.statusBarItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Left,
      100
    );
    this.statusBarItem.command = 'flutter-skill.showQuickActions';
    this.update('disconnected');
  }

  update(status: 'connected' | 'disconnected' | 'connecting', device?: string) {
    const icons = {
      connected: '$(debug-alt)',
      disconnected: '$(debug-disconnect)',
      connecting: '$(loading~spin)'
    };

    const labels = {
      connected: `Flutter: ${device || 'Connected'}`,
      disconnected: 'Flutter: Disconnected',
      connecting: 'Flutter: Connecting...'
    };

    this.statusBarItem.text = `${icons[status]} ${labels[status]}`;
    this.statusBarItem.show();
  }
}
```

#### 1.2 连接状态卡片
- [ ] 创建可视化连接状态卡片
- [ ] 添加设备信息显示
- [ ] 添加 VM Service 端口信息
- [ ] 实现断开连接/刷新按钮

**预览**:
```
╔═══ Connection Status ═══╗
║  🟢 Connected            ║
║  📱 iPhone 16 Pro        ║
║  ⚡ VM Service: :50000   ║
║  [Disconnect] [Refresh]  ║
╚══════════════════════════╝
```

#### 1.3 错误提示优化
- [ ] 替换简单的错误弹窗
- [ ] 添加详细错误原因说明
- [ ] 提供快速修复建议
- [ ] 添加"查看完整指南"链接

**示例**:
```typescript
function showConnectionError(error: Error) {
  const quickFixes = [
    {
      label: '⚡ Add --vm-service-port flag',
      action: () => {
        vscode.env.clipboard.writeText('flutter run --vm-service-port=50000');
        vscode.window.showInformationMessage('Command copied to clipboard!');
      }
    },
    {
      label: '🔄 Restart with flag',
      action: () => restartAppWithFlag()
    }
  ];

  vscode.window.showErrorMessage(
    `Connection failed: ${error.message}`,
    ...quickFixes.map(f => f.label)
  ).then(selected => {
    const fix = quickFixes.find(f => f.label === selected);
    if (fix) fix.action();
  });
}
```

#### 1.4 按钮分组和图标
- [ ] 将操作按钮分组（Launch, Inspect, Screenshot, etc.）
- [ ] 使用 VSCode Codicons
- [ ] 添加工具提示（tooltip）
- [ ] 实现按钮禁用状态

**完成标准**:
- ✅ 状态栏显示正确的连接状态
- ✅ 错误提示包含解决方案
- ✅ 所有按钮都有合适的图标和提示
- ✅ 视觉层次清晰

---

## Week 3-4: 核心功能 🎯

### 目标
实现核心交互功能，提升工作效率

### 任务清单

#### 2.1 Inspector Webview
- [ ] 创建独立的 Inspector Webview 面板
- [ ] 显示应用截图
- [ ] 支持元素高亮
- [ ] 实现点击截图定位元素

**文件**: `vscode-extension/src/views/InspectorView.ts`

```typescript
export class InspectorView {
  private panel: vscode.WebviewPanel | undefined;

  show(elements: UIElement[], screenshot: string) {
    if (!this.panel) {
      this.panel = vscode.window.createWebviewPanel(
        'flutterSkillInspector',
        'Flutter UI Inspector',
        vscode.ViewColumn.Two,
        { enableScripts: true }
      );
    }

    this.panel.webview.html = this.getHtmlContent(elements, screenshot);
    this.panel.reveal();
  }

  private getHtmlContent(elements: UIElement[], screenshot: string) {
    return `
      <!DOCTYPE html>
      <html>
        <body>
          <div class="screenshot-container">
            <img src="${screenshot}" id="appScreenshot" />
            <canvas id="highlightCanvas"></canvas>
          </div>
          <div class="elements-list">
            ${elements.map(e => this.renderElement(e)).join('')}
          </div>
        </body>
      </html>
    `;
  }
}
```

#### 2.2 Interactive Elements 列表
- [ ] 显示所有可交互元素
- [ ] 按类型分组（Button, TextField, etc.）
- [ ] 显示元素属性（位置、大小、文本）
- [ ] 实现搜索过滤

**UI 组件**:
```html
<div class="element-item">
  <div class="element-header">
    <span class="element-icon">🔘</span>
    <span class="element-name">login_button</span>
    <span class="element-type">ElevatedButton</span>
  </div>
  <div class="element-details">
    Text: "Login" • Position: (156, 420) • Size: 120×48
  </div>
  <div class="element-actions">
    <button onclick="tap('login_button')">👆 Tap</button>
    <button onclick="inspect('login_button')">🔍 Inspect</button>
  </div>
</div>
```

#### 2.3 Quick Actions 面板
- [ ] 实现快速操作面板
- [ ] 添加常用操作快捷键
- [ ] 支持自定义操作
- [ ] 保存最近使用的操作

**快捷键**:
```json
{
  "keybindings": [
    {
      "command": "flutter-skill.launchApp",
      "key": "ctrl+shift+f l",
      "mac": "cmd+shift+f l"
    },
    {
      "command": "flutter-skill.inspect",
      "key": "ctrl+shift+f i",
      "mac": "cmd+shift+f i"
    },
    {
      "command": "flutter-skill.screenshot",
      "key": "ctrl+shift+f s",
      "mac": "cmd+shift+f s"
    }
  ]
}
```

#### 2.4 Onboarding 流程
- [ ] 首次启动显示欢迎页面
- [ ] 引导用户完成基本设置
- [ ] 提供快速入门教程
- [ ] 添加示例项目链接

**完成标准**:
- ✅ Inspector 可以显示截图和元素
- ✅ 元素列表可以筛选和搜索
- ✅ 快捷键正常工作
- ✅ 新用户能在 2 分钟内完成首次测试

---

## Week 5-6: 高级功能 🚀

### 目标
添加高级功能，满足专业用户需求

### 任务清单

#### 3.1 Test Builder
- [ ] 创建可视化测试构建器
- [ ] 支持拖拽添加测试步骤
- [ ] 生成测试代码
- [ ] 保存和加载测试用例

**数据结构**:
```typescript
interface TestStep {
  type: 'tap' | 'input' | 'wait' | 'screenshot' | 'assert';
  target?: string;
  value?: any;
  timeout?: number;
}

interface TestCase {
  id: string;
  name: string;
  steps: TestStep[];
  createdAt: Date;
}
```

**UI 示例**:
```
┌─── Test Builder ───┐
│ Test: Login Flow   │
│                    │
│ 1. [👆] Tap         │
│    email_field     │
│    [▶️] [✕]         │
│                    │
│ 2. [⌨️] Input       │
│    "test@test.com" │
│    [▶️] [✕]         │
│                    │
│ [+ Add Step]       │
│ [▶️ Run] [💾 Save]  │
└────────────────────┘
```

#### 3.2 Logs Viewer
- [ ] 实时显示应用日志
- [ ] 支持日志过滤（Info/Warn/Error）
- [ ] 支持搜索和高亮
- [ ] 导出日志功能

**实现**:
```typescript
export class LogsViewer {
  private logs: LogEntry[] = [];

  addLog(entry: LogEntry) {
    this.logs.push(entry);
    this.updateView();

    // Auto-scroll to bottom
    if (this.autoScroll) {
      this.scrollToBottom();
    }
  }

  filter(level: 'all' | 'info' | 'warn' | 'error') {
    const filtered = this.logs.filter(log =>
      level === 'all' || log.level === level
    );
    this.updateView(filtered);
  }

  search(query: string) {
    const results = this.logs.filter(log =>
      log.message.toLowerCase().includes(query.toLowerCase())
    );
    this.updateView(results);
  }
}
```

#### 3.3 History Tracking
- [ ] 记录所有测试操作
- [ ] 显示操作时间线
- [ ] 支持重放历史操作
- [ ] 导出测试报告

**数据模型**:
```typescript
interface HistoryEntry {
  id: string;
  type: 'tap' | 'input' | 'screenshot' | 'inspect';
  timestamp: Date;
  target?: string;
  result: 'success' | 'error';
  duration: number;
  metadata?: any;
}
```

#### 3.4 设置界面
- [ ] 创建设置页面
- [ ] 支持默认设备选择
- [ ] 配置截图质量
- [ ] 自定义快捷键

**设置项**:
```typescript
interface FlutterSkillSettings {
  defaultDevice: string | null;
  vmServicePort: number;
  screenshotQuality: number; // 0-1
  autoLaunchOnStartup: boolean;
  autoReloadOnSave: boolean;
  showNotifications: boolean;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
}
```

**完成标准**:
- ✅ Test Builder 可以创建和运行测试
- ✅ Logs Viewer 实时显示日志
- ✅ History 记录所有操作
- ✅ 设置可以持久化保存

---

## Week 7-8: 打磨优化 ✨

### 目标
优化性能和用户体验细节

### 任务清单

#### 4.1 动画和过渡
- [ ] 添加页面切换动画
- [ ] 元素进入/退出动画
- [ ] Loading 状态动画
- [ ] 支持动画禁用选项

**CSS 动画**:
```css
/* 淡入动画 */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.element-item {
  animation: fadeIn 0.3s ease-out;
}

/* 尊重用户偏好 */
@media (prefers-reduced-motion: reduce) {
  * {
    animation: none !important;
    transition: none !important;
  }
}
```

#### 4.2 快捷键支持
- [ ] 为所有主要功能添加快捷键
- [ ] 显示快捷键提示
- [ ] 支持自定义快捷键
- [ ] 添加快捷键列表页面

**快捷键列表**:
| 功能 | Windows/Linux | macOS |
|-----|--------------|-------|
| Launch App | Ctrl+Shift+F L | Cmd+Shift+F L |
| Inspect | Ctrl+Shift+F I | Cmd+Shift+F I |
| Screenshot | Ctrl+Shift+F S | Cmd+Shift+F S |
| Hot Reload | Ctrl+Shift+F R | Cmd+Shift+F R |

#### 4.3 主题适配
- [ ] 完整支持 VSCode 主题变量
- [ ] 测试浅色/深色/高对比度主题
- [ ] 添加自定义颜色配置
- [ ] 优化图标在不同主题下的显示

**主题测试清单**:
- [ ] Light (Default Light+)
- [ ] Dark (Default Dark+)
- [ ] High Contrast Light
- [ ] High Contrast Dark
- [ ] Popular themes (One Dark Pro, Dracula, etc.)

#### 4.4 性能优化
- [ ] 优化元素列表渲染（虚拟滚动）
- [ ] 优化截图加载（懒加载）
- [ ] 减少不必要的重渲染
- [ ] 添加性能监控

**虚拟滚动实现**:
```typescript
import { VirtualScroller } from '@vscode/virtual-scroller';

const scroller = new VirtualScroller({
  itemHeight: 80,
  items: elements,
  renderItem: (element) => renderElementCard(element)
});
```

**完成标准**:
- ✅ 所有动画流畅（60fps）
- ✅ 快捷键响应时间 < 100ms
- ✅ 支持所有 VSCode 官方主题
- ✅ 1000+ 元素列表滚动流畅

---

## 📊 验收标准

### Phase 1 完成标准
- [ ] 状态栏正确显示连接状态
- [ ] 错误提示包含解决方案
- [ ] 所有按钮有图标和tooltip
- [ ] 通过 5 个用户测试

### Phase 2 完成标准
- [ ] Inspector 显示截图和元素列表
- [ ] 支持点击元素执行操作
- [ ] 新用户 2 分钟内完成首次测试
- [ ] 通过 10 个用户测试

### Phase 3 完成标准
- [ ] Test Builder 可以创建测试用例
- [ ] Logs Viewer 实时显示日志
- [ ] History 记录所有操作
- [ ] 专业用户认可度 > 90%

### Phase 4 完成标准
- [ ] 所有主题显示正常
- [ ] 性能达标（60fps, < 100ms响应）
- [ ] 无障碍功能完整
- [ ] 通过 20+ 用户测试

---

## 🎯 成功指标

### 用户体验指标
- ⏱️ 首次连接时间 < 10秒
- 🎯 新用户完成首次测试 < 2分钟
- 📊 错误自助解决率 > 80%
- ⭐ 用户满意度 > 4.5/5

### 技术指标
- 🚀 UI 响应时间 < 100ms
- 📱 支持 1000+ 元素流畅滚动
- 🎨 所有官方主题兼容
- ♿ 通过 WCAG 2.1 AA 标准

---

## 📝 每周检查点

### Week 1 检查点
- [ ] 状态栏集成完成
- [ ] 错误提示优化完成
- [ ] 基础 UI 改进完成

### Week 3 检查点
- [ ] Inspector Webview 完成
- [ ] Interactive Elements 列表完成
- [ ] Onboarding 流程完成

### Week 5 检查点
- [ ] Test Builder 完成
- [ ] Logs Viewer 完成
- [ ] Settings 界面完成

### Week 7 检查点
- [ ] 所有动画完成
- [ ] 主题适配完成
- [ ] 性能优化完成

---

## 🚀 启动项目

### 1. 创建功能分支
```bash
git checkout -b feature/ui-improvements
```

### 2. 安装依赖
```bash
cd vscode-extension
npm install @vscode/webview-ui-toolkit
npm install @vscode/codicons
```

### 3. 开发环境设置
```bash
# 启动开发模式
npm run watch

# 在 VSCode 中按 F5 启动调试
```

### 4. 提交规范
```bash
# 遵循 Conventional Commits
git commit -m "feat(ui): add status bar integration"
git commit -m "style(ui): improve button layout"
git commit -m "docs(ui): update design guide"
```

---

## 📞 获取帮助

- **设计问题**: 参考 `UI_UX_DESIGN_GUIDE.md`
- **技术问题**: 查看 VSCode Extension API 文档
- **用户反馈**: 创建 GitHub Discussion

---

**开始日期**: TBD
**预计完成**: 8 周后
**负责人**: Flutter Skill Team
