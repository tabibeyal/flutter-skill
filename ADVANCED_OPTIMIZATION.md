# Flutter-Skill 识别率极致优化方案

## 🎯 目标：95%+ 识别率

### 当前问题分析

即使有了 v0.2.25 的优化，仍有一些场景识别率不高：

**低识别场景：**
1. ❌ "帮我看看这个页面有什么问题" → Claude 可能读代码而不是测试 UI
2. ❌ "验证一下表单提交" → 可能分析代码逻辑
3. ❌ "这个按钮能点吗？" → 可能搜索代码
4. ❌ "在手机上看看效果" → 可能只截图而不是交互测试
5. ❌ "自动填写登录信息" → 可能不理解需要 UI 自动化

## 策略 1: 多维度触发词矩阵

### 1.1 构建完整的同义词库

**动作词触发（Action Verbs）：**
```yaml
test_synonyms:
  英文: [test, verify, check, validate, ensure, confirm, examine, inspect]
  中文: [测试, 验证, 检查, 确认, 查看, 检验, 审查]

interact_synonyms:
  英文: [tap, click, press, touch, select, activate, trigger]
  中文: [点击, 点, 按, 触摸, 选择, 激活]

input_synonyms:
  英文: [enter, type, input, fill, write]
  中文: [输入, 填写, 录入, 键入, 填]

view_synonyms:
  英文: [see, view, look, show, display, visualize]
  中文: [看, 查看, 显示, 展示, 可视化]
```

**平台词触发（Platform Keywords）：**
```yaml
ios_keywords: [iOS, iPhone, iPad, simulator, Xcode]
android_keywords: [Android, emulator, AVD, device]
mobile_keywords: [mobile, app, 手机, 应用, 移动端]
```

**测试类型触发（Test Type Keywords）：**
```yaml
ui_test: [UI, interface, screen, page, 界面, 屏幕, 页面]
e2e_test: [E2E, end-to-end, flow, journey, user flow, 流程, 用户流程]
integration_test: [integration, scenario, 集成, 场景]
```

### 1.2 组合模式识别

**模式 1: 动作 + 对象**
```
"点击 登录按钮" → tap
"填写 表单" → enter_text
"查看 界面" → inspect
```

**模式 2: 平台 + 动作**
```
"在 iOS 上测试" → launch_app (iOS)
"Android 模拟器运行" → launch_app (Android)
```

**模式 3: 测试意图**
```
"验证功能正常" → launch_app + inspect + tap
"检查 UI 是否正确" → inspect + screenshot
"自动化登录流程" → enter_text + tap + wait_for_element
```

## 策略 2: 上下文感知增强

### 2.1 对话历史分析

**实现机制：**
在 SKILL.md 中添加上下文提示：

```markdown
## Context Awareness for AI Agents

### Previous Message Analysis

If user's previous messages mentioned:
- Flutter project path → Likely wants to test
- Running/launched app → Ready for interaction
- Specific feature name → Wants to verify that feature
- Bug/issue description → Wants to reproduce/debug

**Example:**
User Message 1: "I'm working on a Flutter login screen"
User Message 2: "测试一下" ← Should trigger flutter-skill (context: login screen)
```

### 2.2 项目上下文检测

```markdown
## Project Context Detection

If current working directory contains:
- `pubspec.yaml` + Flutter dependencies → Flutter project
- `lib/main.dart` → Flutter app entry point
- `ios/` or `android/` directories → Mobile app

When user asks generic "test" in Flutter project context:
✅ Use flutter-skill (UI testing)
❌ Not flutter test (unless explicitly "unit test")
```

## 策略 3: 工具描述超级优化

### 3.1 使用结构化元数据

在 MCP server.dart 中，为每个工具添加更丰富的元数据：

```dart
{
  "name": "launch_app",
  "description": "...", // 保留原有描述

  // 新增：结构化元数据
  "metadata": {
    "triggers": [
      // 英文触发词
      "test app", "test flutter", "run app", "launch app",
      "start app", "open app", "test on iOS", "test on Android",
      "simulator test", "emulator test", "E2E test",
      "integration test", "UI test", "verify feature",

      // 中文触发词
      "测试应用", "测试app", "运行应用", "启动应用",
      "在iOS上测试", "在Android上测试", "模拟器测试",
      "集成测试", "界面测试", "验证功能"
    ],

    "use_when": [
      "User asks to test/verify a Flutter feature",
      "User mentions iOS simulator or Android emulator",
      "User wants to see app behavior on real device/simulator",
      "User asks to validate user flows or interactions"
    ],

    "dont_use_when": [
      "User asks for unit testing (use 'flutter test')",
      "User asks for widget testing (use WidgetTester)",
      "User only wants to build the app (use 'flutter build')"
    ],

    "examples": [
      {
        "user_query": "Test the login feature",
        "action": "launch_app + inspect + enter_text + tap"
      },
      {
        "user_query": "在iOS模拟器测试",
        "action": "launch_app with iOS device"
      }
    ]
  }
}
```

### 3.2 描述模板优化

**当前格式：**
```
"Launch and test a Flutter app on iOS simulator/Android emulator..."
```

**超级优化格式：**
```
[PRIMARY PURPOSE] Launch and test Flutter apps for UI validation
[WHEN TO USE] User says: 'test app' | 'iOS simulator' | 'verify feature' | '测试应用'
[WHAT IT DOES] Starts app on device/simulator, enables UI interaction and validation
[ALTERNATIVES] NOT for unit tests (use 'flutter test') or code analysis
[WORKFLOW] → inspect() to see UI → tap()/enter_text() to interact → screenshot() to verify
[PLATFORMS] iOS Simulator, Android Emulator, Physical Devices
```

## 策略 4: 智能提示系统

### 4.1 主动建议机制

在 SKILL.md 中添加"智能提示"部分：

```markdown
## Intelligent Suggestions for AI Agents

### Auto-Suggest Scenarios

When user mentions these, AI should proactively ask if they want to use flutter-skill:

1. **User describes a visual issue**
   - "The button looks weird"
   - "界面显示不对"
   - → Ask: "Would you like me to launch the app and take a screenshot to see the issue?"

2. **User mentions testing without clarity**
   - "Test this"
   - "验证一下"
   - → Ask: "Do you want to test the UI/feature (use flutter-skill) or run unit tests (flutter test)?"

3. **User asks about UI behavior**
   - "Does the button work?"
   - "能不能点击？"
   - → Auto-use flutter-skill to verify

### Disambiguation Patterns

| User Query | Likely Intent | Tool to Use |
|------------|---------------|-------------|
| "test" + file path | Unit test | flutter test |
| "test" + "screen/UI/button" | UI test | flutter-skill |
| "test" + "simulator" | UI test | flutter-skill |
| "test" + "function/logic" | Unit test | flutter test |
```

### 4.2 工作流程自动推断

```markdown
## Workflow Auto-Detection

AI should recognize common workflows and execute automatically:

### Workflow 1: Feature Verification
**User:** "Verify the login works"

**Auto-Execute:**
1. launch_app() if not connected
2. inspect() → Find email, password, button
3. Ask user: "Should I test with sample credentials?"
4. enter_text() × 2 + tap()
5. wait_for_element() → Home screen
6. Report: ✅ Login successful

### Workflow 2: Visual Debug
**User:** "Why does the screen look wrong?"

**Auto-Execute:**
1. connect_app() or launch_app()
2. screenshot() → Capture current state
3. get_widget_tree() → Analyze layout
4. get_errors() → Check for errors
5. Report findings with screenshot

### Workflow 3: E2E Test
**User:** "自动化测试注册流程"

**Auto-Execute:**
1. launch_app()
2. inspect() → Map out registration form
3. execute_batch([
     enter_text(username),
     enter_text(email),
     enter_text(password),
     tap(register_button),
     wait_for_element(success_message)
   ])
4. screenshot() → Evidence
5. Report: ✅ Registration flow complete
```

## 策略 5: 负面案例学习

### 5.1 明确的"不使用"场景

```markdown
## When NOT to Use Flutter-Skill

### ❌ Code Analysis Tasks
**User:** "分析这段代码的逻辑"
**Correct:** Read source files, analyze code
**Wrong:** Launch app

### ❌ Build/Compilation Tasks
**User:** "Build the APK"
**Correct:** Run 'flutter build apk'
**Wrong:** launch_app()

### ❌ Dependency Management
**User:** "Add a package"
**Correct:** Edit pubspec.yaml, run 'flutter pub get'
**Wrong:** Use flutter-skill

### ❌ Unit Testing
**User:** "Test the calculateTotal function"
**Correct:** Run 'flutter test'
**Wrong:** launch_app()

### ✅ Correct Usage Examples

**User:** "Test if calculateTotal shows correct result in UI"
**Correct:** launch_app() + inspect() → This is UI testing ✅
```

## 策略 6: 多语言支持

### 6.1 中英文双语优化

```dart
// 在 server.dart 中
{
  "name": "inspect",
  "description": """
    [EN] See what UI elements are on screen (buttons, text fields, etc.)
    [CN] 查看屏幕上有哪些UI元素（按钮、文本框等）

    [USE WHEN EN] User asks: 'what's on screen?' | 'list buttons' | 'show elements'
    [USE WHEN CN] 用户询问: '屏幕上有什么？' | '列出按钮' | '显示元素'

    Essential first step for any UI test or validation.
    任何UI测试或验证的必要第一步。
  """,
}
```

### 6.2 口语化表达识别

```yaml
formal_vs_casual:
  formal: "Please verify the login functionality"
  casual: "看看能不能登录" | "试试登录"
  slang: "测测登录" | "搞个登录测试"

  # All should trigger launch_app + test workflow
```

## 策略 7: 实时反馈和学习

### 7.1 使用日志改进

```markdown
## Logging for Continuous Improvement

### Capture These Events

1. **User Query** → Tool Selected → Success/Failure
   ```
   Query: "测试登录"
   Expected: launch_app
   Actual: launch_app ✅
   Success: true
   ```

2. **Missed Invocations**
   ```
   Query: "看看界面对不对"
   Expected: launch_app + screenshot
   Actual: Read source file ❌
   → Add "界面对不对" to triggers
   ```

3. **False Positives**
   ```
   Query: "Test the utils function"
   Expected: flutter test
   Actual: launch_app ❌
   → Add "utils function" to negative patterns
   ```

### Implementation

在 server.dart 中添加：
```dart
void _logToolInvocation(String method, Map params, String userQuery) {
  // Log to ~/.flutter_skill_usage.log
  // Format: timestamp | query | tool | params | success
}
```
```

## 策略 8: Claude Code 特定优化

### 8.1 利用 Claude Code 的 Skill 系统

```yaml
# SKILL.md 头部元数据增强
---
name: flutter-skill
version: 0.2.25
category: testing
tags: [flutter, ui-testing, e2e, mobile, ios, android, automation]
priority: high  # 提高优先级

# 关键：增加 examples 部分
examples:
  - query: "test the flutter app"
    intent: ui_testing
    tools: [launch_app, inspect]

  - query: "在iOS模拟器测试"
    intent: ios_testing
    tools: [launch_app]
    device: iOS

  - query: "验证登录功能"
    intent: feature_verification
    tools: [launch_app, inspect, enter_text, tap]

  - query: "check if button is clickable"
    intent: ui_validation
    tools: [inspect, tap]
---
```

### 8.2 System Prompt 增强

创建 `.claude/prompts/flutter-testing.md`:

```markdown
# Flutter UI Testing Context

When user works with Flutter projects and mentions:
- Testing features/UI
- iOS/Android simulator
- Verifying functionality
- Checking UI elements
- Automating user flows

**Always consider flutter-skill first before:**
- Reading source code
- Running flutter test
- Analyzing logic

**Quick Decision Tree:**
- UI/Visual? → flutter-skill ✅
- Logic/Function? → flutter test ✅
- Code analysis? → Read files ✅
```

## 策略 9: 提示词工程

### 9.1 元提示嵌入

在每个工具描述的开头添加元提示：

```dart
{
  "name": "launch_app",
  "description": """
⚡ PRIORITY TOOL FOR UI TESTING ⚡

If user query contains ANY of these signals, USE THIS TOOL:
✓ Words: test, verify, check, validate, 测试, 验证
✓ Platforms: iOS, Android, simulator, emulator, 模拟器
✓ Contexts: UI, screen, button, form, flow, 界面, 按钮, 表单

DO NOT use flutter test (unit testing) or code reading.

Core Function: Launch and test a Flutter app on iOS simulator/Android emulator...
""",
}
```

### 9.2 反向提示

在其他工具（如 Bash）的描述中添加：

```dart
// 在 Bash tool 描述中
{
  "description": """
    ...existing description...

    ⚠️ For Flutter UI testing, use flutter-skill MCP tool instead.
    Examples that should NOT use Bash:
    - "test the app" → use launch_app
    - "iOS simulator" → use launch_app
    - "verify UI" → use inspect
  """
}
```

## 策略 10: A/B 测试框架

### 10.1 测试用例集

创建 `test_cases.yaml`:

```yaml
test_cases:
  - query: "test this flutter app"
    expected_tool: launch_app
    expected_success: true

  - query: "在iOS模拟器上测试"
    expected_tool: launch_app
    expected_params: { device: iOS }

  - query: "验证登录功能"
    expected_tools: [launch_app, inspect, enter_text, tap]

  - query: "这个按钮能点吗"
    expected_tools: [inspect, tap]

  - query: "自动化测试注册流程"
    expected_tools: [launch_app, execute_batch]

  # 负面案例
  - query: "run unit tests"
    expected_tool: bash (flutter test)
    should_not_use: launch_app

  - query: "analyze this code"
    expected_tool: read
    should_not_use: launch_app
```

### 10.2 自动化验证

```dart
// test/recognition_test.dart
void main() {
  test('Tool recognition accuracy', () async {
    final testCases = loadYaml('test_cases.yaml');
    int correct = 0;
    int total = testCases.length;

    for (var testCase in testCases) {
      // Simulate user query
      final result = await simulateClaude(testCase.query);

      if (result.tool == testCase.expected_tool) {
        correct++;
      } else {
        print('❌ Failed: ${testCase.query}');
        print('   Expected: ${testCase.expected_tool}');
        print('   Got: ${result.tool}');
      }
    }

    final accuracy = (correct / total) * 100;
    print('Accuracy: $accuracy%');
    expect(accuracy, greaterThan(95.0)); // 要求 95%+
  });
}
```

## 实施优先级

### 🔥 高优先级（立即实施）

1. **工具描述元提示**（策略 9.1）
   - 在描述开头添加 ⚡ PRIORITY TOOL
   - 列出明确的触发词

2. **多语言触发词**（策略 6.1）
   - 添加中文描述
   - 支持口语化表达

3. **负面案例**（策略 5.1）
   - 明确何时不使用
   - 与其他工具的区别

### ⚡ 中优先级（本周实施）

4. **上下文感知**（策略 2）
   - 对话历史分析
   - 项目上下文检测

5. **智能提示**（策略 4）
   - 主动建议机制
   - 工作流程自动推断

### 📊 低优先级（持续优化）

6. **日志和学习**（策略 7）
   - 使用日志记录
   - 持续改进触发词

7. **A/B 测试**（策略 10）
   - 测试用例集
   - 自动化验证

## 预期效果

| 优化策略 | 识别率提升 | 实施难度 |
|---------|-----------|---------|
| 元提示嵌入 | +10% | 低 |
| 多语言支持 | +8% | 低 |
| 负面案例 | +5% | 低 |
| 上下文感知 | +7% | 中 |
| 智能提示 | +5% | 中 |
| **总计** | **95%+** | - |
