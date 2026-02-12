# Web SDK & WebBridgeProxy QA Test Report

**Date:** 2026-02-12
**Reviewer:** QA Engineer (Claude Code)
**Files Reviewed:**

- `/Users/cw/development/flutter-skill/sdks/web/flutter-skill.js`
- `/Users/cw/development/flutter-skill/lib/src/bridge/web_bridge_proxy.dart`
- `/Users/cw/development/flutter-skill/lib/src/bridge/bridge_protocol.dart`
- `/Users/cw/development/flutter-skill/lib/src/drivers/bridge_driver.dart`
- `/Users/cw/development/flutter-skill/lib/src/discovery/bridge_discovery.dart`

---

## Summary

**Overall: FAIL** (Score: 62/100)

The code demonstrates a well-thought-out architecture and covers the core protocol contract, but there are several bugs ranging from critical to minor. The most severe issue is a string-escaping vulnerability in the CDP proxy that can cause evaluation failures or injection. Additional issues include incomplete framework change detection, missing shadow DOM support, and a reconnection logic flaw in the bridge driver.

---

## 1. Protocol Compliance

### 1.1 Health Check Response Fields

**Status: PASS**

The protocol spec (`bridge_protocol.dart`) requires: `framework`, `app_name`, `platform`, `capabilities`, `sdk_version`. The proxy's health check at line 185-192 of `web_bridge_proxy.dart` returns all five fields plus a bonus `proxy` field:

```dart
'framework': 'web',
'app_name': 'Web App (via CDP proxy)',
'platform': 'web',
'capabilities': [...bridgeCoreMethods, 'get_logs', 'clear_logs'],
'sdk_version': bridgeProtocolVersion,
'proxy': true,
```

All required fields present. `BridgeServiceInfo.fromHealthCheck()` correctly parses them.

### 1.2 WebSocket Endpoint

**Status: PASS**

The protocol specifies `/ws` as the WebSocket path. The proxy checks for `/ws` at line 198. `BridgeServiceInfo.fromHealthCheck()` constructs `ws://127.0.0.1:$port/ws` at line 96. Both match.

### 1.3 Core Methods Implementation

**Status: PASS**

All 10 core methods listed in `bridgeCoreMethods` are implemented in `flutter-skill.js`:

| Method             | JS Function | Status |
|--------------------|-------------|--------|
| `initialize`       | line 91     | Implemented |
| `screenshot`       | line 231    | Delegates to CDP via `_needs_cdp` |
| `inspect`          | line 95     | Implemented |
| `tap`              | line 110    | Implemented |
| `enter_text`       | line 117    | Implemented |
| `swipe`            | line 142    | Implemented |
| `scroll`           | line 191    | Implemented |
| `find_element`     | line 210    | Implemented |
| `get_text`         | line 216    | Implemented |
| `wait_for_element` | line 225    | Implemented |

Extended methods `get_logs` and `clear_logs` are also implemented.

### 1.4 JSON-RPC 2.0 Format

**Status: PASS (with minor note)**

The proxy sends responses with `jsonrpc`, `id`, `result`/`error` fields (lines 247-258 of `web_bridge_proxy.dart`). Parse error response at line 217-222 correctly returns code `-32700`. The bridge driver sends requests via `buildRpcRequestWithId()` which includes `jsonrpc: "2.0"`, `id`, `method`, and optional `params`.

**Minor note:** The `__FLUTTER_SKILL_CALL__` function in the JS SDK does not use JSON-RPC internally -- it returns plain result objects. This is correct because the proxy wraps the result in a JSON-RPC envelope before sending to the client. However, the screenshot method returns `{ _needs_cdp: true }` which the proxy never checks. See Bug #1 below.

---

## 2. Code Quality: flutter-skill.js

### 2.1 DOM Element Finding

**Status: FAIL -- Minor bugs**

**Bug #2 (Minor): `findElement` text matching is greedy.** Line 53 uses `indexOf` which matches substrings. Searching for text `"OK"` would match an element containing `"BOOK"`. This can cause false positives when tapping or finding elements by text.

**Bug #3 (Minor): Hidden element detection using `offsetParent`.** The check `el.offsetParent !== null` at line 53 (and line 104 in `inspect`) returns `null` for elements with `position: fixed` or `position: sticky`, even if they are visible. Elements inside `<body>` directly (where `<body>` is the offsetParent) also have `offsetParent === null`. The inspect method partially compensates for `<input>` elements (line 104) but not for other fixed-position elements.

**Bug #4 (Minor): No shadow DOM support.** `document.querySelector` and `document.querySelectorAll` do not penetrate shadow DOM boundaries. Web Components using shadow DOM will be invisible to `findElement` and `inspect`. This limits SDK usefulness with modern component libraries (Shoelace, Lit, etc.).

**Bug #5 (Minor): No iframe support.** Elements inside `<iframe>` are not reachable via the current `document.querySelector` calls. Cross-origin iframes would require separate CDP sessions, but same-origin iframes could be traversed.

### 2.2 enter_text and Framework Change Detection

**Status: FAIL -- Major bug**

**Bug #6 (Major): Native setter selection is fragile.** Lines 122-136 always try `HTMLInputElement.prototype` first, then fall back to `HTMLTextAreaElement.prototype`. If the target element is a `<textarea>`, it will incorrectly use the `HTMLInputElement` setter (which exists but is the wrong prototype), potentially causing silent failures or missing React state updates. The code should check the element's tag first:

```javascript
// Current (buggy):
var nativeSetter = Object.getOwnPropertyDescriptor(
  window.HTMLInputElement.prototype, "value"
);
if (!nativeSetter) {
  nativeSetter = Object.getOwnPropertyDescriptor(
    window.HTMLTextAreaElement.prototype, "value"
  );
}

// Correct:
var proto = el instanceof HTMLTextAreaElement
  ? HTMLTextAreaElement.prototype
  : HTMLInputElement.prototype;
var nativeSetter = Object.getOwnPropertyDescriptor(proto, "value");
```

**Bug #7 (Minor): Missing `InputEvent` for modern frameworks.** Some React versions and Angular's reactive forms listen for `InputEvent` (not just `Event("input")`). The current code dispatches `new Event("input")` which lacks `InputEvent`-specific properties like `inputType` and `data`. Vue 3's `v-model` relies on `InputEvent` in some configurations.

### 2.3 Swipe Implementation

**Status: PASS (with note)**

The swipe dispatches `pointerdown`, `pointermove`, `pointerup` in sequence at lines 167-187. This is the correct basic pattern for pointer-event-driven UI frameworks.

**Note:** The swipe fires only a single `pointermove` event. Libraries that rely on continuous movement tracking (e.g., gesture libraries that require multiple intermediate pointermove events to calculate velocity) will not register the swipe properly. This is acceptable for v1 but should be documented as a known limitation.

### 2.4 Console Capture

**Status: PASS**

Console capture at lines 247-270 wraps `console.log`, `console.warn`, and `console.error`. Original functions are preserved and called via `.apply()`. The log buffer is capped at 500 entries (line 254), preventing unbounded memory growth.

**Note:** `console.info`, `console.debug`, and `console.trace` are not captured. This is acceptable but worth noting.

### 2.5 Memory Leak Risks

**Status: PASS**

The log buffer cap at 500 entries (using `shift()`) prevents unbounded growth. No event listeners are registered without cleanup paths. The SDK is loaded once via the IIFE guard at line 18.

---

## 3. Code Quality: web_bridge_proxy.dart

### 3.1 CDP Connection and Reconnection

**Status: FAIL -- Major bug**

**Bug #8 (Major): No CDP reconnection mechanism.** When the CDP WebSocket closes (line 78: `onDone: () => _cdpWs = null`), the proxy simply nullifies the reference. All subsequent `_cdpCall` invocations will throw `Exception('CDP not connected')`. There is no reconnection attempt. If Chrome is restarted, navigates to a new page, or the DevTools connection drops momentarily, the proxy becomes permanently non-functional until manually restarted.

The `BridgeDriver` (client side) has reconnection logic, but the server-side proxy does not. This is a significant gap since the proxy is a long-running process.

### 3.2 JS Expression Injection / Escaping

**Status: FAIL -- Critical bug**

**Bug #1 (Critical): String escaping in `_evaluateInPage` is insufficient.** Line 263:

```dart
final paramsJson = jsonEncode(params).replaceAll("'", "\\'");
final expression =
    "JSON.parse(window.__FLUTTER_SKILL_CALL__('$method', JSON.parse('$paramsJson')))";
```

This has multiple issues:

1. **Backslash in params breaks the expression.** If `params` contains a backslash (e.g., entering text `"C:\new"` or `"line1\nline2"`), `jsonEncode` produces `"C:\\new"` or `"line1\\nline2"`. These backslashes are NOT escaped for the outer single-quoted JS string, causing the JS parser to interpret `\n` as a newline and break the expression.

2. **Newlines in params break the expression.** `jsonEncode` does escape newlines to `\n`, but when embedded in a JS single-quoted string that is not a template literal, the JS parser interprets the escaped characters before `JSON.parse` sees them, potentially corrupting the data.

3. **Method name injection.** The `method` variable is interpolated directly into the JS string without any escaping. While method names are typically controlled, a malicious or malformed method name containing `'` could break out of the string literal.

**Recommended fix:** Use a different transport strategy. Pass params as a separate `Runtime.evaluate` argument or use double-encoding:

```dart
final paramsB64 = base64Encode(utf8.encode(jsonEncode(params)));
final expression = '''
  (function() {
    var p = JSON.parse(atob('$paramsB64'));
    return JSON.parse(window.__FLUTTER_SKILL_CALL__('$method', p));
  })()
''';
```

### 3.3 Screenshot Handling

**Status: FAIL -- Minor bug**

**Bug #9 (Minor): Screenshot result field mismatch.** The proxy's `_handleScreenshot()` at line 285 returns `{'image': result['data']}`. However, CDP's `Page.captureScreenshot` returns `{ data: "<base64>" }` in the CDP result envelope. The code accesses `result['data']` which should work because `_cdpCall` unwraps the CDP response to the `result` field (line 90-91). This is correct.

**However**, there is an inconsistency: the in-page SDK's screenshot method (line 231-235) returns `{ _needs_cdp: true }`, but the proxy at line 232 intercepts the `screenshot` method name before calling `_evaluateInPage`. So the `_needs_cdp` sentinel is never actually used. This is dead code / unused protocol. Not a bug per se, but misleading -- the `_needs_cdp` check that might be expected in `_evaluateInPage` does not exist. If someone adds a new CDP-delegated method, they might incorrectly rely on the `_needs_cdp` pattern.

### 3.4 Health Check Endpoint

**Status: PASS**

The proxy serves the health check at `bridgeHealthPath` (`/.flutter-skill`) with correct JSON content type and all required fields. This is verified in section 1.1.

### 3.5 Error Handling: Chrome Not Running

**Status: FAIL -- Minor bug**

**Bug #10 (Minor): Unhelpful error when Chrome is not running.** If Chrome is not running on the CDP port, `_connectCdp()` will throw a raw `SocketException` from `HttpClient.get()`. The error message will be something like `Connection refused (OS Error: Connection refused, errno = 61)` with no context about what was being attempted or how to fix it. The `start()` method does not catch and wrap this error.

---

## 4. Integration

### 4.1 bridge_discovery.dart Health Check Probing

**Status: PASS (with minor note)**

`BridgeDiscovery.discoverAll()` scans ports `18118..18128` in parallel, sends GET to `bridgeHealthPath`, validates that the response contains `framework`, and parses via `BridgeServiceInfo.fromHealthCheck()`. Timeouts are reasonable: 500ms connection, 800ms response, 500ms body read.

**Note:** The `HttpClient` is not closed in the error/non-200 path at line 65. This is a minor resource leak -- the client's idle connections may linger. Line 59 closes on the success path, and line 63 closes after the status-code check, but if an exception is thrown between lines 44-57, `client.close()` is never called.

**Bug #11 (Minor): HttpClient leak on exception.** The `try/catch` at line 65 catches all exceptions but does not close the `HttpClient` instance created at line 41. While the GC will eventually clean this up, under rapid repeated scans this could exhaust file descriptors.

### 4.2 bridge_driver.dart Protocol Compliance

**Status: PASS (with note)**

The driver correctly:
- Connects via WebSocket to the `wsUri` from discovery
- Sends `initialize` handshake on connect
- Uses `buildRpcRequestWithId` for proper JSON-RPC 2.0 formatting
- Parses responses correctly, handling both `result` and `error`
- Implements reconnection logic with guard against concurrent reconnects

**Bug #12 (Minor): Reconnection skips `initialize` handshake.** The `_reconnect()` method at lines 276-297 creates a new WebSocket connection but does not re-send the `initialize` handshake. The `connect()` method at line 57 does send `initialize`. After a reconnect, the server may not recognize the client as properly initialized, depending on server-side state management.

### 4.3 Timeout Reasonableness

**Status: PASS**

| Location | Timeout | Verdict |
|----------|---------|---------|
| BridgeDiscovery connection | 500ms | Good for port scanning |
| BridgeDiscovery response | 800ms | Good for health check |
| BridgeDriver connect | 5s | Reasonable |
| BridgeDriver RPC call | 30s | Reasonable for screenshot/complex ops |
| BridgeDriver reconnect | 3s | Reasonable |
| WebBridgeProxy CDP call | 15s | Reasonable |

---

## 5. Bugs Summary

| # | Severity | Component | Description |
|---|----------|-----------|-------------|
| 1 | **Critical** | web_bridge_proxy.dart | String escaping in `_evaluateInPage` is broken for params containing backslashes, quotes, or special characters. Can cause JS parse errors or data corruption. |
| 2 | Minor | flutter-skill.js | `findElement` text search matches substrings (e.g., "OK" matches "BOOK"). |
| 3 | Minor | flutter-skill.js | `offsetParent` check misidentifies `position:fixed` elements as hidden. |
| 4 | Minor | flutter-skill.js | No shadow DOM support -- Web Components are invisible. |
| 5 | Minor | flutter-skill.js | No iframe element support. |
| 6 | **Major** | flutter-skill.js | `enter_text` uses `HTMLInputElement` setter for `<textarea>` elements, may fail to trigger React/Vue change detection on textareas. |
| 7 | Minor | flutter-skill.js | Dispatches `Event("input")` instead of `InputEvent` -- some framework bindings may not fire. |
| 8 | **Major** | web_bridge_proxy.dart | No CDP reconnection. If Chrome disconnects, the proxy is permanently broken. |
| 9 | Minor | web_bridge_proxy.dart | `_needs_cdp` sentinel in JS SDK is dead code; screenshot interception is done by method name check only. |
| 10 | Minor | web_bridge_proxy.dart | No user-friendly error message when Chrome is not running. |
| 11 | Minor | bridge_discovery.dart | `HttpClient` not closed on exception path, potential file descriptor leak. |
| 12 | Minor | bridge_driver.dart | Reconnection does not re-send `initialize` handshake. |

**Severity counts:** 1 Critical, 2 Major, 9 Minor

---

## 6. Recommendations

### Immediate Fixes (before any release)

1. **Fix `_evaluateInPage` escaping (Bug #1).** Use base64 encoding to transport params safely:
   ```dart
   final paramsB64 = base64Encode(utf8.encode(jsonEncode(params)));
   final methodSafe = method.replaceAll("'", "\\'").replaceAll('\\', '\\\\');
   final expression = "(function(){var p=JSON.parse(atob('$paramsB64'));"
       "return JSON.parse(window.__FLUTTER_SKILL_CALL__('$methodSafe',p));})()";
   ```

2. **Fix `enter_text` textarea handling (Bug #6).** Check element type before selecting the prototype setter:
   ```javascript
   var proto = (el.tagName === 'TEXTAREA')
     ? HTMLTextAreaElement.prototype
     : HTMLInputElement.prototype;
   ```

3. **Add CDP reconnection (Bug #8).** Detect `_cdpWs` becoming null in `_onCdpMessage`'s `onDone` callback and attempt to reconnect with exponential backoff.

### Short-term Improvements

4. **Fix substring text matching (Bug #2).** Use exact match or word-boundary matching:
   ```javascript
   if (node.textContent.trim() === params.text ||
       node.textContent.trim().indexOf(params.text) === 0)
   ```

5. **Add `initialize` to reconnection flow (Bug #12).**

6. **Wrap Chrome-not-running error (Bug #10)** in a descriptive exception with remediation steps.

7. **Close HttpClient in discovery error path (Bug #11).**

### Long-term Improvements

8. Add shadow DOM traversal for modern Web Component support.
9. Add same-origin iframe element discovery.
10. Dispatch `InputEvent` instead of `Event("input")` for better framework compatibility.
11. Add multi-step pointermove events for swipe to support velocity-based gesture libraries.
12. Capture `console.info` and `console.debug` in addition to log/warn/error.
13. Remove or document the `_needs_cdp` dead code path.

---

## 7. Manual Test Scenarios

The following scenarios should be manually verified in a real browser environment:

### P0 (Must test before release)

1. **Text with special characters.** Call `enter_text` with text containing backslashes, single quotes, double quotes, newlines, and unicode characters. Verify text appears correctly in the input field.
   - Test input: `He said "hello" and typed C:\Users\new`
   - Expected: Text renders correctly; no JS errors in console.

2. **Screenshot capture.** Connect to a running Chrome instance, call `screenshot`, verify base64 PNG data is returned and decodes to a valid image.

3. **Textarea enter_text with React.** Open a React app with a controlled `<textarea>`. Call `enter_text`. Verify React state updates and the value persists after re-render.

4. **CDP disconnect recovery.** While the proxy is running, close and reopen Chrome. Verify behavior (currently expected: permanent failure -- validates Bug #8).

### P1 (Should test)

5. **Inspect on a complex page.** Run `inspect` on a page with 500+ interactive elements. Verify response is complete and performance is acceptable (under 2 seconds).

6. **Swipe on a scrollable container.** Call `swipe` on a horizontally scrollable carousel. Verify the container scrolls.

7. **find_element with fixed-position element.** Create a page with a `position:fixed` button. Call `find_element` by its testId. Verify it is found (currently may fail -- validates Bug #3).

8. **Concurrent RPC calls.** Send 10 rapid RPC calls in parallel. Verify all receive correct responses matched by ID.

9. **Port scan with no apps running.** Run `BridgeDiscovery.discoverAll()` when no bridge apps are running. Verify it returns empty list within 2 seconds and does not leak file descriptors.

### P2 (Good to test)

10. **Shadow DOM element.** Create a page with a Lit or Shoelace component. Call `find_element` for an element inside the shadow root. Verify it is NOT found (documents current limitation).

11. **Large log buffer.** Generate 600+ console.log messages. Verify buffer stays at 500 and oldest entries are evicted.

12. **Proxy with multiple browser tabs.** Start Chrome with multiple tabs. Verify the proxy connects to the first `type: "page"` tab.

13. **WebSocket reconnect in BridgeDriver.** Kill the proxy server while the driver is connected. Verify the driver attempts reconnection on next call.

---

*End of report.*
