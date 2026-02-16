// Flutter Skill guest-js bridge for Tauri frontend
// This runs in the Tauri webview and communicates with the Rust plugin

interface JsonRpcRequest {
  jsonrpc: '2.0';
  method: string;
  params?: Record<string, unknown>;
  id: number;
}

interface JsonRpcResponse {
  jsonrpc: '2.0';
  result?: unknown;
  error?: { code: number; message: string };
  id: number;
}

let requestId = 0;

function buildRequest(method: string, params?: Record<string, unknown>): JsonRpcRequest {
  return { jsonrpc: '2.0', method, params, id: ++requestId };
}

/**
 * Connect to the flutter-skill WebSocket server running in the Tauri backend.
 */
export function connect(port = 18118): Promise<FlutterSkillClient> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    const pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();

    ws.onopen = () => resolve(new FlutterSkillClient(ws, pending));
    ws.onerror = (e) => reject(e);

    ws.onmessage = (ev) => {
      const resp: JsonRpcResponse = JSON.parse(ev.data);
      const p = pending.get(resp.id);
      if (p) {
        pending.delete(resp.id);
        if (resp.error) p.reject(new Error(resp.error.message));
        else p.resolve(resp.result);
      }
    };
  });
}

export class FlutterSkillClient {
  constructor(
    private ws: WebSocket,
    private pending: Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>
  ) {}

  private call(method: string, params?: Record<string, unknown>): Promise<unknown> {
    const req = buildRequest(method, params);
    return new Promise((resolve, reject) => {
      this.pending.set(req.id, { resolve, reject });
      this.ws.send(JSON.stringify(req));
    });
  }

  health() { return this.call('health'); }
  inspect() { return this.call('inspect'); }
  inspectInteractive() { return this.call('inspect_interactive'); }
  tap(selector?: string, ref?: string) { 
    const params: Record<string, unknown> = {};
    if (ref) params.ref = ref;
    else if (selector) params.selector = selector;
    return this.call('tap', params); 
  }
  enterText(text: string, selector?: string, ref?: string) { 
    const params: Record<string, unknown> = { text };
    if (ref) params.ref = ref;
    else if (selector) params.selector = selector;
    return this.call('enter_text', params); 
  }
  screenshot() { return this.call('screenshot'); }
  scroll(dx = 0, dy = 0) { return this.call('scroll', { dx, dy }); }
  getText(selector: string) { return this.call('get_text', { selector }); }
  findElement(params: { selector?: string; text?: string }) { return this.call('find_element', params); }
  waitForElement(selector: string, timeout = 5000) { return this.call('wait_for_element', { selector, timeout }); }

  longPress(params: { key?: string; text?: string; ref?: string; duration?: number }) { return this.call('long_press', params); }
  doubleTap(params: { key?: string; text?: string; ref?: string }) { return this.call('double_tap', params); }
  drag(startX: number, startY: number, endX: number, endY: number) { return this.call('drag', { startX, startY, endX, endY }); }
  tapAt(x: number, y: number) { return this.call('tap_at', { x, y }); }
  longPressAt(x: number, y: number, duration = 500) { return this.call('long_press_at', { x, y, duration }); }
  edgeSwipe(edge: 'left' | 'right' | 'top' | 'bottom', distance = 200) { return this.call('edge_swipe', { edge, distance }); }
  gesture(actions: Array<Record<string, unknown>>) { return this.call('gesture', { actions }); }
  scrollUntilVisible(params: { key?: string; text?: string; direction?: string; maxScrolls?: number }) { return this.call('scroll_until_visible', params); }
  swipeCoordinates(startX: number, startY: number, endX: number, endY: number, durationMs = 300) { return this.call('swipe_coordinates', { startX, startY, endX, endY, durationMs }); }
  getCheckboxState(key: string) { return this.call('get_checkbox_state', { key }); }
  getSliderValue(key: string) { return this.call('get_slider_value', { key }); }
  getRoute() { return this.call('get_route'); }
  getNavigationStack() { return this.call('get_navigation_stack'); }
  getErrors() { return this.call('get_errors'); }
  getPerformance() { return this.call('get_performance'); }
  getFrameStats() { return this.call('get_frame_stats'); }
  getMemoryStats() { return this.call('get_memory_stats'); }
  waitForGone(params: { key?: string; text?: string; timeout?: number }) { return this.call('wait_for_gone', params); }
  diagnose() { return this.call('diagnose'); }
  enableTestIndicators() { return this.call('enable_test_indicators'); }
  getIndicatorStatus() { return this.call('get_indicator_status'); }
  enableNetworkMonitoring() { return this.call('enable_network_monitoring'); }
  getNetworkRequests() { return this.call('get_network_requests'); }
  clearNetworkRequests() { return this.call('clear_network_requests'); }
  goBack() { return this.call('go_back'); }
  pressKey(key: string, modifiers?: string[]) { return this.call('press_key', { key, modifiers }); }
  swipe(direction: string, distance = 300) { return this.call('swipe', { direction, distance }); }

  getRegisteredTools() { return this.call('get_registered_tools'); }
  callTool(name: string, params?: Record<string, unknown>) { return this.call('call_tool', { name, params: params || {} }); }

  close() { this.ws.close(); }
}

// ── WebMCP Tool Registration (runs in Tauri webview) ──

interface ToolDefinition {
  name: string;
  description: string;
  params: Record<string, unknown>;
  handler: (params: Record<string, unknown>) => unknown | Promise<unknown>;
  source: string;
}

declare global {
  interface Window {
    __flutter_skill_tools__?: ToolDefinition[];
  }
}

/**
 * Register a tool that AI agents can discover and invoke.
 * Tools are stored in window.__flutter_skill_tools__ for bridge discovery.
 */
export function registerTool(
  name: string,
  description: string,
  params: Record<string, unknown>,
  handler: (params: Record<string, unknown>) => unknown | Promise<unknown>
): void {
  if (!window.__flutter_skill_tools__) window.__flutter_skill_tools__ = [];
  const tool: ToolDefinition = { name, description: description || '', params: params || {}, handler, source: 'js-registered' };
  const idx = window.__flutter_skill_tools__.findIndex(t => t.name === name);
  if (idx !== -1) window.__flutter_skill_tools__[idx] = tool;
  else window.__flutter_skill_tools__.push(tool);
}
