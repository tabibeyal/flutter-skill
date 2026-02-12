# iOS SDK Code Review - Test Report

**Date:** 2026-02-12
**Reviewer:** QA (Code Review Only - No Device Execution)
**SDK Version:** 1.0.0
**Files Reviewed:**
- `Sources/FlutterSkill/FlutterSkillBridge.swift` (747 lines)
- `Sources/FlutterSkill/FlutterSkillBridge+ViewTraversal.swift` (229 lines)
- `Package.swift` (24 lines)
- `README.md` (200 lines)
- `lib/src/bridge/bridge_protocol.dart` (protocol specification)

---

## Overall Score: 72 / 100

---

## Criterion Results

### 1. Protocol Compliance (10 Core Methods)
**PASS**

All 10 core methods from `bridgeCoreMethods` are implemented in the dispatch switch:

| Method | Implemented | Handler |
|--------|:-----------:|---------|
| `initialize` | Yes | `handleInitialize` |
| `screenshot` | Yes | `handleScreenshot` |
| `inspect` | Yes | `handleInspect` |
| `tap` | Yes | `handleTap` |
| `enter_text` | Yes | `handleEnterText` |
| `swipe` | Yes | `handleSwipe` |
| `scroll` | Yes | `handleScroll` |
| `find_element` | Yes | `handleFindElement` |
| `get_text` | Yes | `handleGetText` |
| `wait_for_element` | Yes | `handleWaitForElement` |

The SDK also implements 4 extended methods: `get_logs`, `clear_logs`, `go_back`, `get_route`.

---

### 2. Health Check Endpoint
**PASS (with minor issue)**

- Serves `GET /.flutter-skill` on the correct path.
- Returns JSON with all required fields: `framework`, `app_name`, `platform`, `capabilities`, `sdk_version`.
- Returns 404 for unknown paths.
- Includes `Connection: close` and `Access-Control-Allow-Origin: *` headers.

Minor issue: The protocol specification defines `bridgeProtocolVersion = '1.0'` but the health check response does not include a `protocol_version` field. The `BridgeServiceInfo.fromHealthCheck` parser does not require it currently, so this is not a breaking issue, but it is a gap if a future protocol version needs to be negotiated.

---

### 3. WebSocket JSON-RPC 2.0 Compliance
**FAIL**

The implementation has significant JSON-RPC 2.0 compliance issues:

- **Missing `jsonrpc` field validation**: The incoming request is not checked for `"jsonrpc": "2.0"`. Per the spec, requests without this field should be rejected.
- **Missing `id` field in responses when id is null/absent**: When `id` is `nil` (a JSON-RPC notification), the SDK still sends a response. Per JSON-RPC 2.0, notifications (requests without `id`) MUST NOT be replied to.
- **Error response for unknown methods is non-compliant** (line 345): Returns `{"result": {"error": "Unknown method: ..."}}` instead of a proper JSON-RPC error response `{"error": {"code": -32601, "message": "Method not found"}}`. This means the client will see a "success" response with an error key buried inside the result object, rather than a protocol-level error.
- **`id` type handling**: JSON-RPC 2.0 allows `id` to be string, number, or null. The code stores it as `Any?` and re-serializes it. This works in practice but `JSONSerialization` may behave unexpectedly with some edge-case types.

---

### 4. Default Port
**PASS**

Port `18118` is correctly defined as `defaultPort` and matches `bridgeDefaultPort` from the protocol spec.

---

### 5. Code Quality
**FAIL**

#### Critical Bugs

**BUG-C1: Dual-protocol NWListener will NOT serve plain HTTP health checks**
Severity: **CRITICAL**

The listener is created with WebSocket options inserted into the protocol stack (line 82):
```swift
params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
```
When NWListener has WebSocket protocol options, ALL incoming connections go through the WebSocket protocol handler. A plain HTTP GET request (like the health check `curl http://localhost:18118/.flutter-skill`) will either:
- Be rejected because it does not contain a WebSocket upgrade handshake, or
- Be passed through as a raw WebSocket frame with unpredictable behavior.

The code comments (lines 106-112, 125-128) claim that "plain HTTP GET requests will still arrive as raw data frames that we parse manually," but this is incorrect. Network.framework with WebSocket options does NOT fall back gracefully to raw TCP for non-WebSocket connections. The health-check endpoint will likely be non-functional.

**Fix:** Use a separate NWListener for HTTP (plain TCP without WebSocket options), or use a two-phase approach where you first read raw bytes, determine if it is a WebSocket upgrade, and then negotiate accordingly. Alternatively, use URLSessionWebSocketTask on the client side and a raw TCP listener that manually handles HTTP parsing and WebSocket upgrades.

**BUG-C2: `@MainActor` class with `NWConnection` callbacks creates threading violation**
Severity: **CRITICAL**

`FlutterSkillBridge` is annotated `@MainActor`, but `NWConnection` callbacks (`receiveMessage`, `stateUpdateHandler`) are dispatched on the queue provided to `connection.start(queue:)`. While the code uses `.main` queue, these closures capture `[weak self]` and call methods on `self` which the compiler may not enforce as `@MainActor`-isolated in all Swift versions. In Swift 5.9 (the minimum from Package.swift), strict concurrency checking may not flag this, but in Swift 6 (strict concurrency mode) these closures would fail to compile because they are not annotated `@Sendable` and cross actor boundaries.

The `Task { @MainActor in ... }` block at line 251 is correctly used for the dispatch call, but the surrounding `handleWebSocketMessage` is called directly from the `receiveMessage` closure, which is not guaranteed to be on the main actor in strict concurrency mode.

**BUG-C3: Force-unwrap of `NWEndpoint.Port` (line 85)**
Severity: **CRITICAL**

```swift
listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
```
`NWEndpoint.Port(rawValue:)` returns a non-optional value for `UInt16` in modern SDKs, but this pattern is fragile. If `port` is `0`, the behavior is undefined. More importantly, the `try` here will never actually throw because `NWListener.init(using:on:)` does not throw in the expected way -- the error would come through the `stateUpdateHandler`. However, the catch block on line 86 would mask initialization issues.

#### Major Bugs

**BUG-M1: `wait_for_element` is synchronous -- provides no actual waiting**
Severity: **Major**

`handleWaitForElement` (line 543-546) simply calls `resolveElement` once and returns immediately. There is no polling, timeout, or retry logic. The README acknowledges this with "Synchronous presence check (server polls)" but the method name and protocol imply the SDK should do the waiting. If the server does the polling externally, this works, but it adds latency from repeated WebSocket round-trips.

**BUG-M2: Screenshot dimensions report pixel size but `UIGraphicsImageRenderer` may produce @1x images**
Severity: **Major**

In `handleScreenshot` (lines 553-570), `UIGraphicsImageRenderer(bounds:)` uses the default trait collection, which on the main screen uses the screen's scale. The returned `width` and `height` are computed as:
```swift
"width": Int(window.bounds.width * UIScreen.main.scale),
"height": Int(window.bounds.height * UIScreen.main.scale),
```
However, the actual PNG produced by `renderer.image` will have dimensions based on the renderer's scale, which defaults to the screen scale. So the width/height should match. BUT `UIScreen.main` is deprecated in iOS 16+ in favor of the window scene's screen. On multi-display setups (iPad + external display), `UIScreen.main` might not match the window's actual screen.

**BUG-M3: `handleSwipe` direction is inverted for UIScrollView**
Severity: **Major**

Lines 458-460:
```swift
var offset = scrollView.contentOffset
offset.x -= dx
offset.y -= dy
```
Where `dx` and `dy` are computed as:
- `"up"`: dy = -distance (so offset.y -= (-distance) = offset.y + distance = scrolls DOWN)
- `"down"`: dy = distance (so offset.y -= distance = scrolls UP)

This means a "swipe up" actually scrolls the content down (reveals content above), which is the opposite of the natural gesture. A "swipe up" gesture should scroll content upward (move viewport down), meaning `offset.y` should INCREASE. The current implementation has the correct physical behavior (swipe up = finger moves up = content shifts down relative to finger = offset decreases) but this contradicts the protocol where "direction" refers to the swipe direction, not scroll direction. This could confuse users depending on convention.

Note: Compare with `handleScroll` where `"up"` correctly decreases offset (scrolls up / reveals content above), and `"down"` increases offset (scrolls down / reveals content below). The semantics of `swipe` and `scroll` should align but they have opposite behavior for the same direction string.

**BUG-M4: `simulateSwipe` does not bounds-check scroll offset**
Severity: **Major**

In `simulateSwipe` (lines 663-676), the content offset is set without any bounds checking:
```swift
offset.x += dx
offset.y += dy
scrollView.setContentOffset(offset, animated: true)
```
This can set offsets outside the valid content range, potentially causing visual glitches or unexpected bouncing behavior. Compare with `handleScroll` which carefully clamps offsets using `adjustedContentInset` and `contentSize`.

#### Minor Bugs

**BUG-m1: `isInteractive` uses force-cast (line 110)**
Severity: **Minor**

```swift
if view is UITextView { return (view as! UITextView).isEditable }
```
While safe because of the preceding `is` check, a more idiomatic approach would be:
```swift
if let textView = view as? UITextView { return textView.isEditable }
```
Force-casts are a code smell and may trigger SwiftLint warnings.

**BUG-m2: `handleEnterText` does not clear existing text**
Severity: **Minor**

The `enter_text` handler replaces text entirely with `textField.text = text`. The protocol does not specify whether `enter_text` should append or replace, but this behavior should be documented. Some test scenarios may expect appending.

**BUG-m3: `logBuffer` is accessed from `NWConnection` callback context**
Severity: **Minor**

While the listener queue is `.main`, `appendLog` is a public method that could be called from any thread. The `logBuffer` array is not thread-safe. If a background thread calls `appendLog`, a data race occurs. Since the class is `@MainActor`, callers should be dispatched to main, but the compiler only enforces this in strict concurrency mode (Swift 6).

**BUG-m4: Memory: Screenshot PNG data is fully in memory as base64**
Severity: **Minor**

A full-screen Retina screenshot (e.g., 1290x2796 on iPhone 15 Pro Max) produces a PNG of roughly 3-8 MB. Base64 encoding adds ~33% overhead. The entire JSON-RPC response could be 4-10 MB, all held in memory simultaneously. For repeated screenshot calls, this could cause memory pressure. Consider streaming or compression.

**BUG-m5: `handleGoBack` checks `presentedViewController` on the nav controller instead of the top VC**
Severity: **Minor**

Line 593 checks `nav.presentedViewController`, but the modal might be presented by a child view controller, not the navigation controller itself. A more thorough approach would check the top view controller chain.

**BUG-m6: Missing `jsonrpc` field in incoming request validation**
Severity: **Minor**

The JSON-RPC parser does not validate that the incoming request contains `"jsonrpc": "2.0"`. A malformed request without this field would still be dispatched.

---

### 6. iOS Specifics (UIKit / Network.framework / @MainActor)
**FAIL**

- **`@MainActor` usage**: Applied at class level, which is correct for UIKit work. However, the NWConnection/NWListener callbacks are not inherently main-actor-isolated (see BUG-C2). The `.main` queue provides runtime safety but not compile-time safety in Swift 6.
- **`UIScreen.main` deprecation**: Used in `handleScreenshot` (line 568). Deprecated in iOS 16. Should use `view.window?.windowScene?.screen?.scale` instead.
- **`UIApplication.shared.windows` deprecation**: Used in the fallback path (line 697). Deprecated in iOS 15. The primary path uses `connectedScenes` which is correct, but the `#available(iOS 15.0, *)` check means the deprecated path is never used (since the minimum deployment is iOS 14). This is fine but the fallback is dead code if the minimum target is raised to iOS 15+.
- **Screenshot `afterScreenUpdates: true`**: This is correct for capturing the latest state but can cause performance issues if called in rapid succession.
- **`drawHierarchy(in:afterScreenUpdates:)`**: Correct for capturing UIKit views. For apps using Metal or SpriteKit layers, this may not capture GPU-rendered content. This is a known UIKit limitation and is acceptable.

---

### 7. NWListener WebSocket -- HTTP + WS on Same Port
**FAIL**

This is the most significant architectural issue (see BUG-C1). The approach of adding WebSocket protocol options to the NWListener's protocol stack means ALL connections are treated as WebSocket connections. Plain HTTP requests for the health check will not be handled correctly.

The correct approach for serving both HTTP and WebSocket on the same port with Network.framework would be one of:
1. Use raw TCP (no WebSocket options), manually parse HTTP requests, and manually perform the WebSocket upgrade handshake when the path is `/ws`.
2. Use two separate listeners on different ports.
3. Use a higher-level framework like Vapor or SwiftNIO (but this contradicts the zero-dependency goal).

The most practical fix within the zero-dependency constraint is option 1: use a raw TCP listener, parse HTTP manually, and implement the WebSocket upgrade handshake (SHA-1 of the Sec-WebSocket-Key + magic string, base64 encoded) and frame parsing manually.

---

### 8. README Accuracy
**PASS (with minor issues)**

The README accurately describes:
- Integration for UIKit and SwiftUI
- Port 18118 and port range 18118-18128
- All 10 core methods and 4 extended methods
- Element identification strategy (key, text, type)
- Log capture ring buffer (500 entries)
- Conditional compilation advice
- Architecture (two files, zero dependencies)
- Minimum requirements (iOS 14, Swift 5.9, Xcode 15)

Minor inaccuracies:
- The README says "flutter-skill server scans ports 18118-18128" but does not mention that the health check may not work due to BUG-C1.
- The SPM integration instructions reference `https://github.com/ai-dashboad/flutter-skill.git` as the package URL, but the `Package.swift` lives in `sdks/ios/`, not the repo root. SPM would need to be pointed at a subdirectory or the repo would need a root `Package.swift`. This integration path is likely broken.

---

## Bug Summary

| ID | Severity | Description |
|----|----------|-------------|
| BUG-C1 | Critical | NWListener with WebSocket options cannot serve plain HTTP health checks |
| BUG-C2 | Critical | `@MainActor` class with NWConnection callbacks has threading model issues for Swift 6 |
| BUG-C3 | Critical | Force-unwrap of `NWEndpoint.Port(rawValue:)` is fragile |
| BUG-M1 | Major | `wait_for_element` does not actually wait -- returns immediately |
| BUG-M2 | Major | Screenshot uses deprecated `UIScreen.main.scale` |
| BUG-M3 | Major | `handleSwipe` direction semantics are inverted compared to `handleScroll` |
| BUG-M4 | Major | `simulateSwipe` sets scroll offset without bounds checking |
| BUG-m1 | Minor | Force-cast in `isInteractive` for UITextView |
| BUG-m2 | Minor | `enter_text` replaces text rather than appending (undocumented) |
| BUG-m3 | Minor | `logBuffer` is not thread-safe for external callers |
| BUG-m4 | Minor | Screenshot base64 can cause memory pressure on high-res devices |
| BUG-m5 | Minor | `go_back` does not check modals on child view controllers |
| BUG-m6 | Minor | No `jsonrpc: "2.0"` validation on incoming requests |

**Total: 3 Critical, 4 Major, 6 Minor**

---

## Recommendations

### Must Fix (Before Release)

1. **Rewrite the network layer to handle both HTTP and WebSocket on the same port.** The current approach of adding WebSocket options to NWListener will not serve plain HTTP health checks. Use raw TCP and manually parse HTTP, performing the WebSocket upgrade only for `/ws` requests.

2. **Fix JSON-RPC 2.0 compliance.** Unknown methods should return a proper error response (`code: -32601`), not a result with an embedded error string. Notifications (no `id`) should not receive responses.

3. **Fix the SPM package path.** If the repo is `flutter-skill` and the package lives at `sdks/ios/`, SPM users cannot add the repo root URL. Either create a root `Package.swift` or update the README with the correct integration path.

### Should Fix

4. **Add bounds checking to `simulateSwipe`** to match the careful clamping in `handleScroll`.

5. **Reconcile swipe vs scroll direction semantics** so that `swipe(direction: "up")` and `scroll(direction: "up")` have consistent, well-documented behavior.

6. **Replace `UIScreen.main.scale` with window-scene-based scale** for iOS 16+ compatibility.

7. **Prepare for Swift 6 strict concurrency** by ensuring all NWConnection callbacks are properly isolated to `@MainActor` using `Task { @MainActor in }` wrappers or `assumeIsolated`.

### Nice to Have

8. Add `protocol_version` to the health-check response for forward compatibility.

9. Consider JPEG compression for screenshots (with quality parameter) to reduce payload size.

10. Add a timeout/retry mechanism to `wait_for_element` so it can poll internally for a configurable duration before returning.

11. Add unit tests (currently the `sdks/ios/` directory contains no test targets in `Package.swift`).

---

## Conclusion

The iOS SDK demonstrates a solid understanding of the bridge protocol and provides good UIKit integration with comprehensive view traversal and element resolution. The code is clean, well-organized, and follows Swift conventions.

However, the **critical networking bug (BUG-C1)** means the SDK likely cannot function as designed -- the health check endpoint will not be reachable by plain HTTP clients when WebSocket options are active on the NWListener. This single issue would prevent discovery by the flutter-skill server and must be resolved before the SDK can be shipped.

The JSON-RPC compliance issues (non-standard error responses, missing notification handling) are also significant and could cause interoperability problems with strict JSON-RPC 2.0 clients.

With the networking layer rewritten and the JSON-RPC issues fixed, this SDK would score in the 85-90 range.
