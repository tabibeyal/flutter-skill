//
//  FlutterSkillBridge.swift
//  FlutterSkill iOS SDK
//
//  Bridge that lets flutter-skill automate native iOS apps (UIKit / SwiftUI).
//  Starts an HTTP + WebSocket server on port 18118 using Network.framework.
//  No external dependencies — uses only Foundation, UIKit, and Network.
//

import CommonCrypto
import Foundation
import Network
import UIKit

// MARK: - Public API

/// Main bridge class. Call `FlutterSkillBridge.shared.start()` in your
/// AppDelegate or SwiftUI App init to enable flutter-skill automation.
@MainActor
public final class FlutterSkillBridge {

    // MARK: Properties

    public static let shared = FlutterSkillBridge()

    public static let sdkVersion = "1.0.0"
    public static let defaultPort: UInt16 = 18118

    public private(set) var isRunning = false

    private var listener: NWListener?
    private var wsConnections: [NWConnection] = []
    private var logBuffer: [String] = []
    private let maxLogEntries = 500
    private var appName: String = ""

    // MARK: Lifecycle

    private init() {}

    /// Start the bridge server. Call once at app launch (typically inside
    /// `application(_:didFinishLaunchingWithOptions:)` or SwiftUI `App.init`).
    ///
    /// - Parameter appName: Human-readable app name reported to flutter-skill.
    /// - Parameter port: TCP port to listen on. Defaults to 18118.
    public func start(appName: String = Bundle.main.appName, port: UInt16 = defaultPort) {
        guard !isRunning else { return }
        self.appName = appName
        startListener(port: port)
    }

    /// Stop the bridge server and disconnect all clients.
    public func stop() {
        listener?.cancel()
        listener = nil
        for conn in wsConnections {
            conn.cancel()
        }
        wsConnections.removeAll()
        upgradedConnections.removeAll()
        isRunning = false
        appendLog("[FlutterSkill] Bridge stopped")
    }

    // MARK: Log capture

    /// Append a log entry to the ring buffer. Apps can call this directly,
    /// or the SDK hooks `print` output automatically when `captureStdout` is used.
    public func appendLog(_ message: String) {
        logBuffer.append(message)
        if logBuffer.count > maxLogEntries {
            logBuffer.removeFirst()
        }
    }

    // MARK: - Listener Setup

    /// Connections that have completed the WebSocket handshake and are in frame mode.
    private var upgradedConnections: Set<ObjectIdentifier> = []

    private func startListener(port: UInt16) {
        // Use plain TCP — no WebSocket options in the protocol stack.
        // This allows us to serve both plain HTTP health checks and
        // WebSocket connections on the same port by inspecting raw bytes.
        let params = NWParameters.tcp

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            appendLog("[FlutterSkill] Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                self?.appendLog("[FlutterSkill] Bridge listening on port \(port)")
            case .failed(let error):
                self?.appendLog("[FlutterSkill] Listener failed: \(error)")
                self?.isRunning = false
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: .main)
    }

    // MARK: - Connection Handling

    /// Accept a new raw TCP connection and read the initial bytes to determine
    /// whether it is a plain HTTP request or a WebSocket upgrade.
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.readHTTPRequest(on: connection)
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    /// Read raw bytes from the connection, expecting an HTTP request.
    /// This is used for the initial request on every new TCP connection.
    private func readHTTPRequest(on connection: NWConnection) {
        // Read up to 8 KB for the initial HTTP request (headers only).
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
            [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.appendLog("[FlutterSkill] Receive error: \(error)")
                connection.cancel()
                return
            }

            guard let data = content, !data.isEmpty else {
                if isComplete {
                    connection.cancel()
                }
                return
            }

            self.routeHTTPRequest(data: data, on: connection)
        }
    }

    /// Parse the incoming HTTP request and route to health check or WebSocket upgrade.
    private func routeHTTPRequest(data: Data, on connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            connection.cancel()
            return
        }

        let lines = request.components(separatedBy: "\r\n")
        let firstLine = lines.first ?? ""
        let parts = firstLine.components(separatedBy: " ")
        let method = parts.count > 0 ? parts[0] : ""
        let path = parts.count > 1 ? parts[1] : ""

        // Parse headers into a dictionary (case-insensitive lookup).
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break } // end of headers
            if let colonIndex = line.firstIndex(of: ":") {
                let key = line[line.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        if method == "GET" && path == "/.flutter-skill" {
            // Health check endpoint — respond with JSON and close.
            self.respondHealthCheck(on: connection)
        } else if method == "GET" && path == "/ws"
                    && headers["upgrade"]?.lowercased() == "websocket"
                    && headers["sec-websocket-key"] != nil {
            // WebSocket upgrade request — perform the handshake.
            let wsKey = headers["sec-websocket-key"]!
            self.performWebSocketHandshake(key: wsKey, on: connection)
        } else {
            // 404 for anything else.
            let notFound = "HTTP/1.1 404 Not Found\r\n"
                + "Content-Length: 0\r\n"
                + "Connection: close\r\n"
                + "\r\n"
            connection.send(
                content: notFound.data(using: .utf8),
                completion: .contentProcessed({ _ in
                    connection.cancel()
                })
            )
        }
    }

    // MARK: - HTTP Health Check

    private func respondHealthCheck(on connection: NWConnection) {
        let capabilities = Self.allCapabilities
        let body: [String: Any] = [
            "framework": "ios-native",
            "app_name": appName,
            "platform": "ios",
            "capabilities": capabilities,
            "sdk_version": Self.sdkVersion,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            connection.cancel()
            return
        }

        let header = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(jsonData.count)\r\n"
            + "Access-Control-Allow-Origin: *\r\n"
            + "Connection: close\r\n"
            + "\r\n"
        let response = header + jsonString
        connection.send(
            content: response.data(using: .utf8),
            completion: .contentProcessed({ _ in
                connection.cancel()
            })
        )
    }

    // MARK: - WebSocket Handshake

    /// Perform the server-side WebSocket handshake (RFC 6455 section 4.2.2).
    /// Computes the Sec-WebSocket-Accept value and sends the 101 response,
    /// then transitions the connection into WebSocket frame mode.
    private func performWebSocketHandshake(key: String, on connection: NWConnection) {
        let magic = "258EAFA5-E914-47DA-95CA-5AB5FE82AD80"
        let combined = key + magic
        let acceptKey = sha1Base64(combined)

        let response = "HTTP/1.1 101 Switching Protocols\r\n"
            + "Upgrade: websocket\r\n"
            + "Connection: Upgrade\r\n"
            + "Sec-WebSocket-Accept: \(acceptKey)\r\n"
            + "\r\n"

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.appendLog("[FlutterSkill] WS handshake send error: \(error)")
                connection.cancel()
                return
            }

            // Mark as upgraded and start reading WebSocket frames.
            self.upgradedConnections.insert(ObjectIdentifier(connection))
            if !self.wsConnections.contains(where: { $0 === connection }) {
                self.wsConnections.append(connection)
            }
            self.appendLog("[FlutterSkill] WebSocket client connected")
            self.readWebSocketFrame(on: connection)
        }))
    }

    /// Compute SHA-1 hash and return base64-encoded result using CommonCrypto.
    private func sha1Base64(_ string: String) -> String {
        let data = Data(string.utf8)
        // Use CommonCrypto for SHA-1 (available on all Apple platforms).
        var digest = [UInt8](repeating: 0, count: 20) // SHA-1 produces 20 bytes
        data.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }

    // MARK: - WebSocket Frame Reading

    /// Read the next WebSocket frame from an upgraded connection.
    /// Implements a minimal RFC 6455 frame parser for text, close, and ping frames.
    private func readWebSocketFrame(on connection: NWConnection) {
        // Read at least 2 bytes (the minimum WebSocket frame header).
        connection.receive(minimumIncompleteLength: 2, maximumLength: 2) {
            [weak self] header, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.appendLog("[FlutterSkill] WS frame header error: \(error)")
                self.closeAndRemove(connection)
                return
            }

            guard let header = header, header.count >= 2 else {
                if isComplete { self.closeAndRemove(connection) }
                return
            }

            let byte0 = header[0]
            let byte1 = header[1]
            let opcode = byte0 & 0x0F
            let isMasked = (byte1 & 0x80) != 0
            var payloadLen = UInt64(byte1 & 0x7F)

            // Determine extended payload length.
            if payloadLen == 126 {
                // Read 2 more bytes for 16-bit length.
                self.readBytes(count: 2, on: connection) { extData in
                    guard let extData = extData else {
                        self.closeAndRemove(connection)
                        return
                    }
                    payloadLen = UInt64(extData[0]) << 8 | UInt64(extData[1])
                    self.readFramePayload(
                        opcode: opcode, isMasked: isMasked,
                        payloadLen: payloadLen, on: connection
                    )
                }
            } else if payloadLen == 127 {
                // Read 8 more bytes for 64-bit length.
                self.readBytes(count: 8, on: connection) { extData in
                    guard let extData = extData else {
                        self.closeAndRemove(connection)
                        return
                    }
                    payloadLen = 0
                    for i in 0..<8 {
                        payloadLen = (payloadLen << 8) | UInt64(extData[i])
                    }
                    self.readFramePayload(
                        opcode: opcode, isMasked: isMasked,
                        payloadLen: payloadLen, on: connection
                    )
                }
            } else {
                // Payload length fits in 7 bits.
                self.readFramePayload(
                    opcode: opcode, isMasked: isMasked,
                    payloadLen: payloadLen, on: connection
                )
            }
        }
    }

    /// Read exactly `count` bytes from the connection.
    private func readBytes(count: Int, on connection: NWConnection, completion: @escaping (Data?) -> Void) {
        guard count > 0 else {
            completion(Data())
            return
        }
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
            if error != nil || data == nil || data!.count < count {
                completion(nil)
            } else {
                completion(data)
            }
        }
    }

    /// Read the masking key (if present) and payload, then handle the frame.
    private func readFramePayload(
        opcode: UInt8, isMasked: Bool,
        payloadLen: UInt64, on connection: NWConnection
    ) {
        let maskLen = isMasked ? 4 : 0
        let totalToRead = Int(payloadLen) + maskLen

        // Guard against absurdly large frames (limit to 16 MB).
        guard payloadLen <= 16 * 1024 * 1024 else {
            appendLog("[FlutterSkill] WS frame too large: \(payloadLen) bytes")
            closeAndRemove(connection)
            return
        }

        if totalToRead == 0 {
            // No payload (e.g., close frame with no body).
            handleDecodedFrame(opcode: opcode, payload: Data(), on: connection)
            return
        }

        readBytes(count: totalToRead, on: connection) { [weak self] rawData in
            guard let self = self, let rawData = rawData else {
                self?.closeAndRemove(connection)
                return
            }

            var payload: Data
            if isMasked {
                let mask = rawData.prefix(4)
                let masked = rawData.dropFirst(4)
                var unmasked = Data(count: Int(payloadLen))
                for i in 0..<Int(payloadLen) {
                    unmasked[i] = masked[masked.startIndex + i] ^ mask[mask.startIndex + (i % 4)]
                }
                payload = unmasked
            } else {
                payload = rawData
            }

            self.handleDecodedFrame(opcode: opcode, payload: payload, on: connection)
        }
    }

    /// Handle a decoded WebSocket frame based on its opcode.
    private func handleDecodedFrame(opcode: UInt8, payload: Data, on connection: NWConnection) {
        switch opcode {
        case 0x01: // Text frame
            handleWebSocketTextMessage(data: payload, on: connection)
            // Continue reading the next frame.
            readWebSocketFrame(on: connection)

        case 0x08: // Close frame
            // Reply with a close frame and tear down.
            let closeFrame = buildWSFrame(opcode: 0x08, payload: Data())
            connection.send(content: closeFrame, completion: .contentProcessed({ [weak self] _ in
                self?.closeAndRemove(connection)
            }))

        case 0x09: // Ping — reply with Pong carrying the same payload.
            let pongFrame = buildWSFrame(opcode: 0x0A, payload: payload)
            connection.send(content: pongFrame, completion: .contentProcessed({ [weak self] _ in
                self?.readWebSocketFrame(on: connection)
            }))

        case 0x0A: // Pong — ignore, continue reading.
            readWebSocketFrame(on: connection)

        default:
            // Unsupported opcode — close with protocol error (1002).
            let statusBody = Data([0x03, 0xEA]) // status code 1002 in network byte order
            let closeFrame = buildWSFrame(opcode: 0x08, payload: statusBody)
            connection.send(content: closeFrame, completion: .contentProcessed({ [weak self] _ in
                self?.closeAndRemove(connection)
            }))
        }
    }

    // MARK: - WebSocket Frame Writing

    /// Build a server-to-client WebSocket frame (unmasked, per RFC 6455).
    private func buildWSFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()

        // FIN bit + opcode
        frame.append(0x80 | opcode)

        // Payload length (server frames are never masked).
        let length = payload.count
        if length < 126 {
            frame.append(UInt8(length))
        } else if length <= 65535 {
            frame.append(126)
            frame.append(UInt8((length >> 8) & 0xFF))
            frame.append(UInt8(length & 0xFF))
        } else {
            frame.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((length >> shift) & 0xFF))
            }
        }

        frame.append(payload)
        return frame
    }

    /// Send a text message over WebSocket.
    private func sendWSText(_ text: Data, on connection: NWConnection) {
        let frame = buildWSFrame(opcode: 0x01, payload: text)
        connection.send(content: frame, completion: .contentProcessed({ _ in }))
    }

    // MARK: - WebSocket Message Handling

    /// Handle a decoded text-frame payload as a JSON-RPC message.
    private func handleWebSocketTextMessage(data: Data, on connection: NWConnection) {
        // Parse JSON-RPC request
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rpcMethod = json["method"] as? String else {
            sendWSError(on: connection, id: nil, code: -32700, message: "Parse error")
            return
        }

        let id = json["id"] // may be Int or null for notifications
        let params = json["params"] as? [String: Any] ?? [:]

        // Dispatch on main thread for UIKit safety
        Task { @MainActor in
            let result = self.dispatch(method: rpcMethod, params: params)
            self.sendWSDispatchResult(on: connection, id: id, result: result)
        }
    }

    private func sendWSDispatchResult(on connection: NWConnection, id: Any?, result: DispatchResult) {
        switch result {
        case .success(let dict):
            sendWSResult(on: connection, id: id, result: dict)
        case .error(let code, let message):
            sendWSError(on: connection, id: id, code: code, message: message)
        }
    }

    private func sendWSResult(on connection: NWConnection, id: Any?, result: [String: Any]) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result,
        ]
        if let id = id {
            response["id"] = id
        }

        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        sendWSText(data, on: connection)
    }

    private func sendWSError(on connection: NWConnection, id: Any?, code: Int, message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message,
            ] as [String: Any],
        ]
        if let id = id {
            response["id"] = id
        }

        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        sendWSText(data, on: connection)
    }

    private func closeAndRemove(_ connection: NWConnection) {
        connection.cancel()
        removeConnection(connection)
    }

    private func removeConnection(_ connection: NWConnection) {
        wsConnections.removeAll(where: { $0 === connection })
        upgradedConnections.remove(ObjectIdentifier(connection))
    }

    // MARK: - Capabilities

    static let allCapabilities: [String] = [
        // Core
        "initialize", "screenshot", "inspect", "tap", "enter_text",
        "swipe", "scroll", "find_element", "get_text", "wait_for_element",
        // Extended
        "get_logs", "clear_logs", "go_back", "get_route",
    ]

    // MARK: - JSON-RPC Dispatch

    /// Result type from dispatch: either a success result dict or a JSON-RPC error.
    private enum DispatchResult {
        case success([String: Any])
        case error(code: Int, message: String)
    }

    private func dispatch(method: String, params: [String: Any]) -> DispatchResult {
        switch method {
        case "initialize":
            return .success(handleInitialize(params))
        case "inspect":
            return .success(handleInspect(params))
        case "tap":
            return .success(handleTap(params))
        case "enter_text":
            return .success(handleEnterText(params))
        case "swipe":
            return .success(handleSwipe(params))
        case "scroll":
            return .success(handleScroll(params))
        case "find_element":
            return .success(handleFindElement(params))
        case "get_text":
            return .success(handleGetText(params))
        case "wait_for_element":
            return .success(handleWaitForElement(params))
        case "screenshot":
            return .success(handleScreenshot(params))
        case "get_logs":
            return .success(handleGetLogs(params))
        case "clear_logs":
            return .success(handleClearLogs(params))
        case "go_back":
            return .success(handleGoBack(params))
        case "get_route":
            return .success(handleGetRoute(params))
        default:
            return .error(code: -32601, message: "Method not found: \(method)")
        }
    }

    // MARK: - Core Method Implementations

    private func handleInitialize(_ params: [String: Any]) -> [String: Any] {
        return [
            "success": true,
            "framework": "ios-native",
            "sdk_version": Self.sdkVersion,
            "app_name": appName,
            "platform": "ios",
        ]
    }

    private func handleInspect(_ params: [String: Any]) -> [String: Any] {
        guard let window = Self.keyWindow else {
            return ["elements": [Any]()]
        }
        let elements = window.flutterSkill_interactiveElements()
        return ["elements": elements.map { $0.toDictionary() }]
    }

    private func handleTap(_ params: [String: Any]) -> [String: Any] {
        guard let element = resolveElement(params) else {
            return ["success": false, "message": "Element not found"]
        }

        if let control = element as? UIControl {
            control.sendActions(for: .touchUpInside)
            return ["success": true, "message": "Tapped (sendActions)"]
        }

        // For non-UIControl views (SwiftUI, custom views), use accessibility
        if element.accessibilityActivate() {
            return ["success": true, "message": "Tapped (accessibilityActivate)"]
        }

        // Fallback: simulate touch via hit-test point
        let center = element.superview?.convert(element.center, to: nil) ?? element.center
        simulateTap(at: center, in: element.window)
        return ["success": true, "message": "Tapped (simulated touch)"]
    }

    private func handleEnterText(_ params: [String: Any]) -> [String: Any] {
        let text = params["text"] as? String ?? ""
        guard let element = resolveElement(params) else {
            return ["success": false, "message": "Element not found"]
        }

        if let textField = element as? UITextField {
            textField.becomeFirstResponder()
            textField.text = text
            textField.sendActions(for: .editingChanged)
            NotificationCenter.default.post(
                name: UITextField.textDidChangeNotification, object: textField
            )
            return ["success": true, "message": "Text entered in UITextField"]
        }

        if let textView = element as? UITextView {
            textView.becomeFirstResponder()
            textView.text = text
            textView.delegate?.textViewDidChange?(textView)
            NotificationCenter.default.post(
                name: UITextView.textDidChangeNotification, object: textView
            )
            return ["success": true, "message": "Text entered in UITextView"]
        }

        if let searchBar = element as? UISearchBar {
            searchBar.becomeFirstResponder()
            searchBar.text = text
            searchBar.delegate?.searchBar?(searchBar, textDidChange: text)
            return ["success": true, "message": "Text entered in UISearchBar"]
        }

        return ["success": false, "message": "Element is not a text input"]
    }

    private func handleSwipe(_ params: [String: Any]) -> [String: Any] {
        let direction = params["direction"] as? String ?? "up"
        let distance = CGFloat((params["distance"] as? NSNumber)?.doubleValue ?? 300)

        // If a key is specified, find that element; otherwise swipe on the key window.
        let target: UIView
        if let element = resolveElement(params) {
            target = element
        } else if let window = Self.keyWindow {
            target = window
        } else {
            return ["success": false, "message": "No target for swipe"]
        }

        let bounds = target.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let centerInWindow = target.convert(center, to: nil)

        var dx: CGFloat = 0
        var dy: CGFloat = 0
        switch direction {
        case "up": dy = -distance
        case "down": dy = distance
        case "left": dx = -distance
        case "right": dx = distance
        default: break
        }

        let endPoint = CGPoint(x: centerInWindow.x + dx, y: centerInWindow.y + dy)

        // Use accessibility scroll for UIScrollView subclasses
        if let scrollView = target as? UIScrollView {
            var offset = scrollView.contentOffset
            offset.x -= dx
            offset.y -= dy
            scrollView.setContentOffset(offset, animated: true)
            return ["success": true, "message": "Swiped via scroll offset"]
        }

        // Fallback: use accessibility scroll direction
        let axDirection = accessibilityScrollDirection(for: direction)
        if target.accessibilityScroll(axDirection) {
            return ["success": true, "message": "Swiped via accessibility"]
        }

        // Last resort: synthesize touch events
        simulateSwipe(from: centerInWindow, to: endPoint, in: target.window)
        return ["success": true, "message": "Swiped (simulated touch)"]
    }

    private func handleScroll(_ params: [String: Any]) -> [String: Any] {
        let direction = params["direction"] as? String ?? "down"
        let distance = CGFloat((params["distance"] as? NSNumber)?.doubleValue ?? 300)

        // Find scroll view
        let scrollView: UIScrollView?
        if let element = resolveElement(params) as? UIScrollView {
            scrollView = element
        } else if let element = resolveElement(params) {
            scrollView = element.flutterSkill_findEnclosingScrollView()
        } else if let window = Self.keyWindow {
            scrollView = window.flutterSkill_findFirstScrollView()
        } else {
            scrollView = nil
        }

        guard let sv = scrollView else {
            return ["success": false, "message": "No UIScrollView found"]
        }

        var offset = sv.contentOffset
        switch direction {
        case "up": offset.y = max(offset.y - distance, -sv.adjustedContentInset.top)
        case "down":
            let maxY = sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom
            offset.y = min(offset.y + distance, max(maxY, 0))
        case "left": offset.x = max(offset.x - distance, -sv.adjustedContentInset.left)
        case "right":
            let maxX = sv.contentSize.width - sv.bounds.width + sv.adjustedContentInset.right
            offset.x = min(offset.x + distance, max(maxX, 0))
        default: break
        }

        sv.setContentOffset(offset, animated: true)
        return ["success": true, "message": "Scrolled"]
    }

    private func handleFindElement(_ params: [String: Any]) -> [String: Any] {
        guard let element = resolveElement(params) else {
            return ["found": false]
        }
        let desc = ElementDescriptor(view: element)
        return ["found": true, "element": desc.toDictionary()]
    }

    private func handleGetText(_ params: [String: Any]) -> [String: Any] {
        guard let element = resolveElement(params) else {
            return ["text": NSNull()]
        }

        if let label = element as? UILabel {
            return ["text": label.text ?? ""]
        }
        if let textField = element as? UITextField {
            return ["text": textField.text ?? ""]
        }
        if let textView = element as? UITextView {
            return ["text": textView.text ?? ""]
        }
        if let button = element as? UIButton {
            return ["text": button.titleLabel?.text ?? ""]
        }

        // Generic fallback: accessibility label
        return ["text": element.accessibilityLabel ?? ""]
    }

    private func handleWaitForElement(_ params: [String: Any]) -> [String: Any] {
        let element = resolveElement(params)
        return ["found": element != nil]
    }

    private func handleScreenshot(_ params: [String: Any]) -> [String: Any] {
        guard let window = Self.keyWindow else {
            return ["success": false, "message": "No key window"]
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        guard let pngData = image.pngData() else {
            return ["success": false, "message": "Failed to render PNG"]
        }

        let base64 = pngData.base64EncodedString()
        return [
            "success": true,
            "format": "png",
            "encoding": "base64",
            "data": base64,
            "width": Int(window.bounds.width * UIScreen.main.scale),
            "height": Int(window.bounds.height * UIScreen.main.scale),
        ]
    }

    // MARK: - Extended Method Implementations

    private func handleGetLogs(_ params: [String: Any]) -> [String: Any] {
        return ["logs": logBuffer]
    }

    private func handleClearLogs(_ params: [String: Any]) -> [String: Any] {
        logBuffer.removeAll()
        return ["success": true]
    }

    private func handleGoBack(_ params: [String: Any]) -> [String: Any] {
        guard let nav = Self.topNavigationController else {
            return ["success": false, "message": "No UINavigationController found"]
        }
        if nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
            return ["success": true, "message": "Popped view controller"]
        }
        // Try dismiss if presented modally
        if let presented = nav.presentedViewController {
            presented.dismiss(animated: true)
            return ["success": true, "message": "Dismissed modal"]
        }
        return ["success": false, "message": "Nothing to go back to"]
    }

    private func handleGetRoute(_ params: [String: Any]) -> [String: Any] {
        let topVC = Self.topViewController
        let name = topVC.map { String(describing: type(of: $0)) } ?? "unknown"
        let title = topVC?.title ?? topVC?.navigationItem.title
        var result: [String: Any] = ["route": name]
        if let title = title {
            result["title"] = title
        }
        return result
    }

    // MARK: - Element Resolution

    /// Resolve a UIView from the params. Supports: key (accessibilityIdentifier),
    /// text (accessibilityLabel / visible text), and type (class name).
    private func resolveElement(_ params: [String: Any]) -> UIView? {
        guard let window = Self.keyWindow else { return nil }

        if let key = params["key"] as? String, !key.isEmpty {
            // Search by accessibilityIdentifier first
            if let found = window.flutterSkill_findView(accessibilityIdentifier: key) {
                return found
            }
            // Then by accessibilityLabel
            if let found = window.flutterSkill_findView(accessibilityLabel: key) {
                return found
            }
        }

        if let text = params["text"] as? String, !text.isEmpty {
            if let found = window.flutterSkill_findView(accessibilityLabel: text) {
                return found
            }
            if let found = window.flutterSkill_findView(containingText: text) {
                return found
            }
        }

        if let type = params["type"] as? String, !type.isEmpty {
            if let found = window.flutterSkill_findView(ofTypeName: type) {
                return found
            }
        }

        return nil
    }

    // MARK: - Touch Simulation Helpers

    private func simulateTap(at point: CGPoint, in window: UIWindow?) {
        guard let window = window else { return }
        guard let hitView = window.hitTest(point, with: nil) else { return }

        // For UIControl, use sendActions
        if let control = hitView as? UIControl {
            control.sendActions(for: .touchUpInside)
            return
        }

        // Try accessibility activation
        _ = hitView.accessibilityActivate()
    }

    private func simulateSwipe(from start: CGPoint, to end: CGPoint, in window: UIWindow?) {
        guard let window = window else { return }
        guard let hitView = window.hitTest(start, with: nil) else { return }

        // If the hit view or an ancestor is a scroll view, adjust offset
        if let scrollView = hitView.flutterSkill_findEnclosingScrollView() {
            let dx = start.x - end.x
            let dy = start.y - end.y
            var offset = scrollView.contentOffset
            offset.x += dx
            offset.y += dy
            scrollView.setContentOffset(offset, animated: true)
        }
    }

    private func accessibilityScrollDirection(for direction: String) -> UIAccessibilityScrollDirection {
        switch direction {
        case "up": return .up
        case "down": return .down
        case "left": return .left
        case "right": return .right
        default: return .down
        }
    }

    // MARK: - UIKit Helpers

    private static var keyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        }
    }

    private static var topViewController: UIViewController? {
        guard let root = keyWindow?.rootViewController else { return nil }
        return topVC(from: root)
    }

    private static var topNavigationController: UINavigationController? {
        var vc = topViewController
        while let current = vc {
            if let nav = current.navigationController {
                return nav
            }
            vc = current.parent
        }
        // Check if root is a nav controller
        if let nav = keyWindow?.rootViewController as? UINavigationController {
            return nav
        }
        return nil
    }

    private static func topVC(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topVC(from: presented)
        }
        if let nav = vc as? UINavigationController,
           let visible = nav.visibleViewController {
            return topVC(from: visible)
        }
        if let tab = vc as? UITabBarController,
           let selected = tab.selectedViewController {
            return topVC(from: selected)
        }
        return vc
    }
}

// MARK: - Bundle Helper

extension Bundle {
    var appName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Unknown App"
    }
}

