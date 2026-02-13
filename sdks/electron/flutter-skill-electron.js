const { WebSocketServer } = require('ws');
const { BrowserWindow } = require('electron');
const http = require('http');

const DEFAULT_PORT = 18118;
const SDK_VERSION = '1.0.0';

class FlutterSkillElectron {
  constructor(options = {}) {
    this.port = options.port || DEFAULT_PORT;
    this.appName = options.appName || 'electron-app';
    this.wss = null;
    this.httpServer = null;
    this.window = options.window || null;
    this.logs = [];
    this.maxLogs = 500;
    this.navigationHistory = ['home'];
  }

  start() {
    // Create HTTP server for health check + WebSocket upgrade
    this.httpServer = http.createServer((req, res) => {
      if (req.url === '/.flutter-skill') {
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify({
          framework: 'electron',
          app_name: this.appName,
          platform: 'electron',
          sdk_version: SDK_VERSION,
          capabilities: [
            'initialize', 'inspect', 'tap', 'enter_text', 'get_text',
            'find_element', 'wait_for_element', 'scroll', 'swipe',
            'screenshot', 'go_back', 'get_logs', 'clear_logs',
          ],
        }));
      } else {
        res.writeHead(404);
        res.end('Not Found');
      }
    });

    this.wss = new WebSocketServer({ server: this.httpServer });
    this.httpServer.listen(this.port, '127.0.0.1');
    console.log(`[flutter-skill-electron] Bridge on port ${this.port}`);

    this.wss.on('connection', (ws) => {
      ws.on('message', async (data) => {
        let req;
        try {
          req = JSON.parse(data);
        } catch {
          ws.send(JSON.stringify({ jsonrpc: '2.0', error: { code: -32700, message: 'Parse error' }, id: null }));
          return;
        }

        try {
          const result = await this._handle(req.method, req.params || {});
          ws.send(JSON.stringify({ jsonrpc: '2.0', result, id: req.id }));
        } catch (err) {
          ws.send(JSON.stringify({
            jsonrpc: '2.0',
            error: { code: -32000, message: err.message || String(err) },
            id: req.id,
          }));
        }
      });
    });
  }

  stop() {
    if (this.wss) this.wss.close();
    if (this.httpServer) this.httpServer.close();
  }

  log(level, message) {
    this.logs.push(`[${level}] ${message}`);
    if (this.logs.length > this.maxLogs) this.logs.shift();
  }

  _getWindow() {
    return this.window || BrowserWindow.getFocusedWindow() || BrowserWindow.getAllWindows()[0];
  }

  // Resolve a key/selector/text to a CSS selector
  _resolveSelector(params) {
    if (params.selector) return params.selector;
    if (params.key) return `#${params.key}`;
    if (params.element) return params.element;
    return null;
  }

  async _handle(method, params) {
    const win = this._getWindow();

    switch (method) {
      case 'initialize':
        return {
          success: true,
          framework: 'electron',
          sdk_version: SDK_VERSION,
          platform: 'electron',
        };

      case 'inspect':
        return this._inspect(win);

      case 'tap':
        return this._tap(win, params);

      case 'enter_text':
        return this._enterText(win, params);

      case 'get_text':
        return this._getText(win, params);

      case 'find_element':
        return this._findElement(win, params);

      case 'wait_for_element':
        return this._waitForElement(win, params);

      case 'scroll':
        return this._scroll(win, params);

      case 'swipe':
        return this._swipe(win, params);

      case 'screenshot':
        return this._screenshot(win);

      case 'go_back':
        return this._goBack(win);

      case 'get_logs':
        return { logs: [...this.logs] };

      case 'clear_logs':
        this.logs = [];
        return { success: true };

      default:
        throw new Error(`Unknown method: ${method}`);
    }
  }

  async _inspect(win) {
    if (!win) return { elements: [] };
    const elements = await win.webContents.executeJavaScript(`
      (function() {
        const results = [];
        function walk(el) {
          if (!el || el.nodeType !== 1) return;
          const style = window.getComputedStyle(el);
          if (style.display === 'none' || style.visibility === 'hidden') return;

          const tag = el.tagName.toLowerCase();
          const isInteractive = el.matches('button, input, select, textarea, a, [role="button"], [onclick], label');
          const hasId = !!el.id;
          const hasText = !el.children.length && (el.textContent || '').trim().length > 0;

          if (isInteractive || hasId || hasText) {
            const rect = el.getBoundingClientRect();
            results.push({
              type: _mapType(el),
              key: el.id || null,
              tag: tag,
              text: (el.value || el.textContent || '').trim().slice(0, 200) || null,
              bounds: { x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height) },
              visible: rect.width > 0 && rect.height > 0,
              enabled: !el.disabled,
              clickable: el.matches('button, a, [role="button"], [onclick]') || el.onclick != null,
            });
          }

          for (const child of el.children) walk(child);
        }

        function _mapType(el) {
          const tag = el.tagName.toLowerCase();
          if (tag === 'button' || el.matches('[role="button"]')) return 'button';
          if (tag === 'input') {
            const t = el.type;
            if (t === 'checkbox') return 'checkbox';
            if (t === 'radio') return 'radio';
            if (t === 'text' || t === 'email' || t === 'password' || t === 'search' || t === 'number') return 'text_field';
            return 'input';
          }
          if (tag === 'textarea') return 'text_field';
          if (tag === 'select') return 'dropdown';
          if (tag === 'a') return 'link';
          if (tag === 'img') return 'image';
          if (tag === 'label') return 'label';
          if (tag === 'h1' || tag === 'h2' || tag === 'h3') return 'heading';
          return 'text';
        }

        walk(document.body);
        return results;
      })();
    `);
    return { elements };
  }

  async _tap(win, params) {
    if (!win) return { success: false, message: 'No window' };
    const sel = this._resolveSelector(params);
    const textMatch = params.text;

    const result = await win.webContents.executeJavaScript(`
      (function() {
        let el = null;
        if (${JSON.stringify(sel)}) {
          el = document.querySelector(${JSON.stringify(sel || '')});
        }
        if (!el && ${JSON.stringify(textMatch)}) {
          const tw = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          while (tw.nextNode()) {
            if (tw.currentNode.textContent.includes(${JSON.stringify(textMatch || '')})) {
              el = tw.currentNode.parentElement;
              break;
            }
          }
        }
        if (!el) return { success: false, message: 'Element not found' };
        el.click();
        return { success: true };
      })();
    `);
    return result;
  }

  async _enterText(win, params) {
    if (!win) return { success: false, message: 'No window' };
    const sel = this._resolveSelector(params);
    const text = params.text || '';
    if (!sel) return { success: false, message: 'Missing key/selector' };

    const result = await win.webContents.executeJavaScript(`
      (function() {
        const el = document.querySelector(${JSON.stringify(sel)});
        if (!el) return { success: false, message: 'Element not found: ${sel}' };
        el.focus();
        el.value = ${JSON.stringify(text)};
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        return { success: true };
      })();
    `);
    return result;
  }

  async _getText(win, params) {
    if (!win) return { text: null };
    const sel = this._resolveSelector(params);
    if (!sel) return { text: null };

    const result = await win.webContents.executeJavaScript(`
      (function() {
        const el = document.querySelector(${JSON.stringify(sel)});
        if (!el) return { text: null };
        return { text: (el.value || el.textContent || '').trim() };
      })();
    `);
    return result;
  }

  async _findElement(win, params) {
    if (!win) return { found: false };
    const sel = this._resolveSelector(params);
    const textMatch = params.text;

    const result = await win.webContents.executeJavaScript(`
      (function() {
        if (${JSON.stringify(sel)}) {
          const el = document.querySelector(${JSON.stringify(sel || '')});
          if (el) {
            const rect = el.getBoundingClientRect();
            return { found: true, element: {
              tag: el.tagName.toLowerCase(),
              key: el.id || null,
              text: (el.value || el.textContent || '').trim().slice(0, 200),
              bounds: { x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height) },
            }};
          }
        }
        if (${JSON.stringify(textMatch)}) {
          const tw = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          while (tw.nextNode()) {
            if (tw.currentNode.textContent.includes(${JSON.stringify(textMatch || '')})) {
              const p = tw.currentNode.parentElement;
              return { found: true, element: { tag: p.tagName.toLowerCase(), key: p.id || null, text: tw.currentNode.textContent.trim().slice(0, 200) }};
            }
          }
        }
        return { found: false };
      })();
    `);
    return result;
  }

  async _waitForElement(win, params) {
    if (!win) return { found: false };
    const sel = this._resolveSelector(params);
    const textMatch = params.text;
    const timeout = params.timeout || 5000;

    const result = await win.webContents.executeJavaScript(`
      new Promise((resolve) => {
        const start = Date.now();
        const check = () => {
          let found = false;
          if (${JSON.stringify(sel)}) {
            found = !!document.querySelector(${JSON.stringify(sel || '')});
          } else if (${JSON.stringify(textMatch)}) {
            const tw = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while (tw.nextNode()) {
              if (tw.currentNode.textContent.includes(${JSON.stringify(textMatch || '')})) { found = true; break; }
            }
          }
          if (found) return resolve({ found: true });
          if (Date.now() - start > ${timeout}) return resolve({ found: false });
          requestAnimationFrame(check);
        };
        check();
      });
    `);
    return result;
  }

  async _scroll(win, params) {
    if (!win) return { success: false };
    const direction = params.direction || 'down';
    const distance = params.distance || 300;
    const sel = this._resolveSelector(params);

    let dx = 0, dy = 0;
    switch (direction) {
      case 'up': dy = -distance; break;
      case 'down': dy = distance; break;
      case 'left': dx = -distance; break;
      case 'right': dx = distance; break;
    }

    await win.webContents.executeJavaScript(`
      (function() {
        const target = ${sel ? `document.querySelector(${JSON.stringify(sel)})` : 'null'} || document.scrollingElement || document.body;
        target.scrollBy(${dx}, ${dy});
      })();
    `);
    return { success: true };
  }

  async _swipe(win, params) {
    // Swipe = scroll for web contexts
    return this._scroll(win, params);
  }

  async _screenshot(win) {
    if (!win) return { success: false, message: 'No window' };
    const image = await win.webContents.capturePage();
    const base64 = image.toPNG().toString('base64');
    return { success: true, image: base64, format: 'png', encoding: 'base64' };
  }

  async _goBack(win) {
    if (!win) return { success: false, message: 'No window' };

    // Try app-level back handler first (SPA navigation)
    const handled = await win.webContents.executeJavaScript(`
      (function() {
        // Check for custom back handler
        if (typeof window.__flutterSkillGoBack === 'function') {
          window.__flutterSkillGoBack();
          return true;
        }
        // Try clicking a visible back button
        const backBtns = document.querySelectorAll('[id*="back"], [class*="back"], [aria-label*="back"], [aria-label*="Back"]');
        for (const btn of backBtns) {
          if (btn.offsetParent !== null) { btn.click(); return true; }
        }
        return false;
      })();
    `);

    if (handled) return { success: true };

    // Fall back to browser navigation
    const canGoBack = win.webContents.canGoBack();
    if (canGoBack) {
      win.webContents.goBack();
      return { success: true };
    }

    await win.webContents.executeJavaScript('window.history.back()');
    return { success: true };
  }
}

module.exports = { FlutterSkillElectron };
