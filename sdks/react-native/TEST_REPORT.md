# React Native SDK -- QA Test Report

**Date:** 2026-02-12
**Reviewer:** QA Code Review (static analysis, no device execution)
**Files Reviewed:**
- `sdks/react-native/FlutterSkill.js`
- `sdks/react-native/package.json`
- `sdks/react-native/README.md`
- `lib/src/bridge/bridge_protocol.dart` (protocol specification)

---

## Overall Score: 72 / 100

---

## Criterion Results

### 1. Protocol Compliance -- PASS

All 10 core bridge methods defined in `bridge_protocol.dart` are implemented:

| Method | Implemented | Notes |
|--------|------------|-------|
| `initialize` | Yes | Returns framework, sdk_version, platform, app_name |
| `screenshot` | Yes | Returns `{ _needs_native: true }` (delegates to proxy) |
| `inspect` | Yes | Returns registered elements with measured bounds |
| `tap` | Yes | Via `onPress` prop or accessibility fallback |
| `enter_text` | Yes | Via `onChangeText` or `setNativeProps` |
| `swipe` | Yes | Via `dispatchViewManagerCommand` (Android only -- see bugs) |
| `scroll` | Yes | Via `scrollTo` / `scrollToOffset` |
| `find_element` | Yes | By testID, text, or accessibilityLabel |
| `get_text` | Yes | From `props.value` or registered text |
| `wait_for_element` | Yes | Synchronous check, proxy polls |

Extended methods implemented: `get_logs`, `clear_logs`, `get_route`, `go_back`.

### 2. Health Check -- PASS

- Endpoint: `GET /.flutter-skill` on the correct path.
- Response JSON includes all required fields: `framework`, `app_name`, `platform`, `capabilities`, `sdk_version`.
- Content-Type header set to `application/json`.
- Fields match the `BridgeServiceInfo.fromHealthCheck` parser expectations.

### 3. WebSocket / JSON-RPC 2.0 -- PASS (with minor issues)

- WebSocket upgrade on `GET /ws` with correct `Sec-WebSocket-Accept` computation.
- JSON-RPC responses include `jsonrpc: "2.0"`, `id`, and either `result` or `error`.
- Standard error codes used: `-32700` (Parse error), `-32601` (Method not found), `-32000` (internal error).
- Frame encode/decode handles text frames, close frames, ping frames correctly.
- SHA-1 implementation is correct for WebSocket handshake purposes.

### 4. Default Port -- PASS

- `BRIDGE_PORT = 18118` matches `bridgeDefaultPort` in the protocol spec.
- Configurable via `options.port` parameter.

### 5. Code Quality -- FAIL

Multiple bugs and issues found (see Bugs section below).

### 6. React Native Specifics -- FAIL

Several React Native API usage issues (see Bugs section below).

### 7. README Accuracy -- PASS

The README accurately describes:
- Installation steps (npm/yarn + pod install).
- Initialization pattern with `__DEV__` guard.
- Component registration API with correct signatures.
- All supported methods match the implementation.
- Architecture diagram is correct.
- The `_needs_native` screenshot delegation is documented.
- Port configuration and conflict advice is correct.

One minor inaccuracy: README says "React Navigation 5+" but the code does not validate the version.

---

## Bugs Found

### Critical

**C1: Swipe does nothing on iOS**
- **Location:** `methods.swipe`, lines 339-345
- **Description:** The swipe implementation only dispatches a native command on Android (`if (Platform.OS === 'android')`). On iOS, the function measures the element, calculates start/end coordinates, and returns `{ success: true }` without actually performing any action. This silently claims success while doing nothing.
- **Impact:** Swipe is non-functional on iOS (50%+ of target users).
- **Fix:** Implement an iOS swipe path. Options include using `scrollTo` on the nearest scrollable ancestor, or dispatching a synthetic pan gesture via the Gesture Responder system. At minimum, return `{ success: false, message: 'Swipe not implemented on iOS' }` instead of false success.

**C2: WebSocket frame buffer consumed-bytes calculation uses payload string length, not byte length**
- **Location:** `_handleConnection`, lines 799-805
- **Description:** After decoding a frame, consumed bytes are calculated using `frame.payload.length`. However, `frame.payload` is a JavaScript string (from `Buffer.toString('utf-8')`). For any payload containing multi-byte UTF-8 characters, `string.length` returns the number of UTF-16 code units, not the number of bytes. This causes the buffer slice position to be wrong, corrupting all subsequent frames in the same TCP segment.
- **Impact:** Any JSON-RPC message containing non-ASCII characters (e.g., Unicode text in element labels, internationalized app names) will corrupt the WebSocket stream and break the connection.
- **Fix:** Track the consumed byte count from the raw buffer, not from the decoded string. Either return the byte count from `_decodeWsFrame` or compute it from the raw frame header:
  ```js
  // In _decodeWsFrame, also return totalBytes consumed
  return { opcode, payload: payload.toString('utf-8'), totalBytes: offset + payloadLen };
  ```

**C3: Ping response uses wrong opcode**
- **Location:** `_handleConnection`, lines 816-818
- **Description:** When a ping frame (opcode 0x09) is received, the code responds by calling `_encodeWsFrame(frame.payload)`. However, `_encodeWsFrame` always sets opcode 0x81 (FIN + text), not 0x8A (FIN + pong). This sends a text frame instead of a proper pong frame, which violates RFC 6455 Section 5.5.3.
- **Impact:** WebSocket clients that rely on ping/pong for keepalive will not receive valid pong responses and may disconnect.
- **Fix:** Create a `_encodeWsPongFrame` function or add an opcode parameter to `_encodeWsFrame`:
  ```js
  function _encodeWsFrame(text, opcode = 0x81) {
    // ... same logic but use the opcode parameter for header[0]
  }
  // Ping handler:
  socket.write(_encodeWsFrame(frame.payload, 0x8A));
  ```

### Major

**M1: `UIManager.measure` callback may never fire -- no timeout or error handling**
- **Location:** `_getAccessibilityTree` (line 132), `_measureElement` (line 194)
- **Description:** `UIManager.measure` invokes its callback asynchronously via the native bridge. If the node handle becomes invalid (component unmounts between `findNodeHandle` and `measure`), the callback may never fire on some React Native versions. This leaves the Promise permanently pending.
- **Impact:** A single unmounted component can cause `inspect` or `find_element` to hang forever, blocking the WebSocket connection.
- **Fix:** Add a timeout wrapper:
  ```js
  new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), 2000);
    UIManager.measure(nodeHandle, (x, y, w, h, px, py) => {
      clearTimeout(timer);
      resolve(w != null ? { x: px, y: py, width: w, height: h } : null);
    });
  });
  ```

**M2: `registerComponent` with `ref` callback receives `null` on unmount -- registers null**
- **Location:** `registerComponent`, lines 85-88
- **Description:** When used as a ref callback (`ref={ref => registerComponent('id', ref)}`), React calls the callback with `null` when the component unmounts. The guard `if (!testID || !ref) return;` prevents the null write, but the old entry with the stale ref remains in the registry. The stale ref will then cause `findNodeHandle` to return null or throw on subsequent operations.
- **Impact:** After a component unmounts and re-registers (e.g., during navigation), the registry may contain stale entries. Calling `tap` or `find_element` on a stale entry will fail silently or throw.
- **Fix:** When `ref` is null, treat it as an unregister:
  ```js
  function registerComponent(testID, ref, extras) {
    if (!testID) return;
    if (!ref) {
      _componentRegistry.delete(testID);
      return;
    }
    _componentRegistry.set(testID, { ref, ...(extras || {}) });
  }
  ```

**M3: `scroll` with `scrollTo` passes absolute positions, not deltas from current scroll position**
- **Location:** `methods.scroll`, lines 371-375
- **Description:** `ref.scrollTo({ x: dx, y: dy, animated: true })` where `dx`/`dy` are the raw distance values. `ScrollView.scrollTo` takes absolute pixel positions, not deltas. The first `scroll down 300` call scrolls to y=300, but a second `scroll down 300` call also scrolls to y=300 (not y=600). This means repeated scroll commands have no cumulative effect.
- **Impact:** Scrolling only ever goes to the initial distance offset, never further. Users cannot scroll through long lists incrementally.
- **Fix:** Read the current scroll offset first (via `ref.scrollTo` or track it internally), or use `scrollToOffset({ offset: currentOffset + distance })` for FlatList. Alternatively, document this as a limitation.

**M4: No connection close frame sent on server shutdown**
- **Location:** `destroyFlutterSkill`, lines 945-954
- **Description:** When shutting down, the server calls `socket.destroy()` on all WebSocket clients without first sending a WebSocket close frame (opcode 0x08). This is a protocol violation (RFC 6455 Section 7.1.1).
- **Impact:** Clients will see an abrupt TCP reset instead of a clean WebSocket shutdown, potentially losing in-flight responses.
- **Fix:** Send a close frame before destroying:
  ```js
  const closeFrame = Buffer.from([0x88, 0x02, 0x03, 0xE8]); // 1000 Normal Closure
  try { s.write(closeFrame); } catch(e) {}
  setTimeout(() => { try { s.destroy(); } catch(e) {} }, 100);
  ```

**M5: `tap` reads `component.props.onPress` but class component refs do not expose props**
- **Location:** `methods.tap`, line 240
- **Description:** When a ref is obtained via `ref={r => register('id', r)}`, the ref for a class component is the component instance (which does have `props`), but for a function component it is `null` unless `forwardRef` is used, and for native views the ref is a native handle that does NOT have a `props` property. The code assumes `component.props.onPress` is accessible, which is not guaranteed for function components wrapped with `forwardRef` (the ref points to the underlying host element, not the component instance).
- **Impact:** `tap` will fail silently (fall through to accessibility fallback) for most function components, which are the dominant pattern in modern React Native.
- **Fix:** Document that the `extras` object should include an `onPress` callback, or store the callback during registration:
  ```js
  registerComponent('id', ref, { onPress: handlePress });
  ```

### Minor

**m1: `_stringToUtf8Array` does not handle surrogate pairs (codepoints > U+FFFF)**
- **Location:** `_stringToUtf8Array`, lines 631-641
- **Description:** The function only handles codepoints up to U+FFFF (3-byte UTF-8). JavaScript strings use UTF-16, so characters like emoji (U+1F600) appear as surrogate pairs and need 4-byte UTF-8 encoding. This only affects the SHA-1 used for WebSocket handshake, and `Sec-WebSocket-Key` is always ASCII, so this is unlikely to cause issues in practice.
- **Impact:** Theoretical only. No real-world impact since WebSocket keys are base64/ASCII.

**m2: `_handleJsonRpc` does not validate the `jsonrpc` field**
- **Location:** `_handleJsonRpc`, lines 739-780
- **Description:** The JSON-RPC 2.0 spec (Section 4) requires the `jsonrpc` field to be exactly `"2.0"`. The implementation does not check this. A request with `jsonrpc: "1.0"` or no `jsonrpc` field would still be processed.
- **Impact:** Low. The flutter-skill proxy always sends `"2.0"`, but this is a spec compliance gap.

**m3: Health check response does not include `protocol_version`**
- **Location:** `_handleConnection`, lines 869-875
- **Description:** The protocol file defines `bridgeProtocolVersion = '1.0'` but the health check response does not include a `protocol_version` field. The `BridgeServiceInfo.fromHealthCheck` parser does not look for it either, so there is no mismatch today, but it would be useful for forward-compatibility.
- **Impact:** Low. No current consumer requires it.

**m4: No JSON-RPC batch request support**
- **Location:** `_handleJsonRpc`, line 741
- **Description:** JSON-RPC 2.0 Section 6 specifies that an array of request objects should be treated as a batch. The implementation calls `JSON.parse` and treats the result as a single object. An array would cause `parsed.method` to be undefined, returning "Method not found".
- **Impact:** Low. The flutter-skill proxy does not send batch requests currently.

**m5: Console capture is installed globally and never restored**
- **Location:** `_installConsoleCapture`, lines 59-72
- **Description:** Calling `initFlutterSkill` permanently monkey-patches `console.log/warn/error`. Calling `destroyFlutterSkill` does not restore the originals.
- **Impact:** Minor memory and performance overhead if the SDK is initialized and destroyed during tests but the console patches remain.
- **Fix:** Restore originals in `destroyFlutterSkill`:
  ```js
  console.log = _origLog;
  console.warn = _origWarn;
  console.error = _origError;
  ```

**m6: `AccessibilityInfo` is imported but never used**
- **Location:** Line 18
- **Description:** `AccessibilityInfo` is imported from `react-native` but never referenced in the code.
- **Impact:** Dead import. No runtime effect but adds to bundle size analysis noise.

**m7: `Buffer` usage assumes Node.js-like environment**
- **Location:** Multiple places (lines 549, 693, 707, etc.)
- **Description:** `Buffer.alloc`, `Buffer.from`, `Buffer.concat` are used throughout. React Native does not have a built-in `Buffer` global. The `react-native-tcp-socket` library provides it, but this dependency is implicit and fragile.
- **Impact:** If `react-native-tcp-socket` changes its polyfill behavior, the SDK will crash with `ReferenceError: Buffer is not defined`.
- **Fix:** Add a defensive check at init time or explicitly import a `Buffer` polyfill.

**m8: `sdk_version` is `'1.0.0'` but protocol spec uses `'1.0'` for `bridgeProtocolVersion`**
- **Location:** Line 25 vs. protocol line 10
- **Description:** The SDK reports `sdk_version: '1.0.0'` while the protocol defines `bridgeProtocolVersion = '1.0'`. These are semantically different things (SDK version vs. protocol version), but it could cause confusion. The protocol's `sdk_version` field is just a free-form string so this is not a strict violation.
- **Impact:** Cosmetic / potential confusion.

---

## Summary

| Category | Count |
|----------|-------|
| Critical bugs | 3 |
| Major bugs | 5 |
| Minor bugs | 8 |
| **Total** | **16** |

### Scoring Breakdown

| Criterion | Weight | Score | Weighted |
|-----------|--------|-------|----------|
| Protocol compliance | 20 | 95 | 19.0 |
| Health check | 10 | 95 | 9.5 |
| WebSocket / JSON-RPC | 20 | 70 | 14.0 |
| Default port | 5 | 100 | 5.0 |
| Code quality | 25 | 50 | 12.5 |
| React Native specifics | 15 | 55 | 8.25 |
| README accuracy | 5 | 90 | 4.5 |
| **Total** | **100** | | **72.75** |

---

## Recommendations

### Must-fix before release

1. **Fix C2 (frame buffer byte count):** This will cause data corruption for any non-ASCII content. Track raw byte length, not decoded string length.
2. **Fix C3 (ping/pong opcode):** Trivial fix, but violates the WebSocket RFC and will break keepalive.
3. **Fix C1 (iOS swipe):** Either implement iOS swipe or return an honest error instead of false success.
4. **Fix M2 (stale registry entries):** Auto-unregister when ref callback receives null.
5. **Fix M1 (measure timeout):** Add a timeout to prevent hanging Promises.

### Should-fix

6. **Fix M3 (absolute vs. relative scroll):** Scroll behavior is unintuitive -- repeated calls do not accumulate.
7. **Fix M5 (tap for function components):** Modern RN apps are predominantly function components; the tap-via-props pattern rarely works.
8. **Restore console on destroy (m5).**
9. **Remove unused `AccessibilityInfo` import (m6).**
10. **Add explicit Buffer polyfill check (m7).**

### Nice-to-have

11. Add JSON-RPC `jsonrpc` field validation (m2).
12. Add `protocol_version` to health check response (m3).
13. Consider JSON-RPC batch support (m4).
14. Add a WebSocket close frame on shutdown (M4).

### Testing recommendations

15. Write unit tests for `_sha1`, `_decodeWsFrame`, `_encodeWsFrame`, and `_parseHttpRequest`.
16. Create an integration test that connects a real WebSocket client to the TCP server.
17. Test with multi-byte UTF-8 content (Chinese/Japanese characters, emoji) to validate frame parsing.
18. Test the component registration lifecycle: mount, unmount, remount, and verify no stale refs.
