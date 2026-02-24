//! High-level browser operations built on CDP.
//! Each operation minimizes CDP round-trips by pushing logic into the browser.

use crate::cdp::CdpConnection;
use base64::Engine;
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Arc;

/// Navigate to a URL. Returns the final URL.
pub async fn navigate(conn: &Arc<CdpConnection>, url: &str) -> Result<Value, String> {
    // Check current URL first — skip if already there
    let current = conn
        .call(
            "Runtime.evaluate",
            json!({"expression": "location.href", "returnByValue": true}),
        )
        .await?;
    let current_url = current["value"].as_str().unwrap_or("");
    if current_url == url {
        return Ok(json!({"navigated": false, "url": url, "reason": "already_there"}));
    }

    conn.call("Page.navigate", json!({"url": url})).await?;

    // Wait for load
    let mut rx = conn.on_event("Page.loadEventFired");
    tokio::select! {
        _ = rx.recv() => {},
        _ = tokio::time::sleep(std::time::Duration::from_secs(10)) => {},
    }
    conn.remove_listeners("Page.loadEventFired");

    Ok(json!({"navigated": true, "url": url}))
}

/// Evaluate JS expression. Returns the result value.
pub async fn evaluate(conn: &Arc<CdpConnection>, expression: &str) -> Result<Value, String> {
    let result = conn
        .call(
            "Runtime.evaluate",
            json!({
                "expression": expression,
                "returnByValue": true,
                "awaitPromise": true,
            }),
        )
        .await?;

    if let Some(exc) = result.get("exceptionDetails") {
        return Err(format!("JS exception: {exc}"));
    }

    Ok(result
        .get("result")
        .and_then(|r| r.get("value"))
        .cloned()
        .unwrap_or(Value::Null))
}

/// Take a screenshot. Returns base64 JPEG data.
pub async fn screenshot(conn: &Arc<CdpConnection>, quality: u8) -> Result<String, String> {
    let result = conn
        .call(
            "Page.captureScreenshot",
            json!({
                "format": "jpeg",
                "quality": quality,
                "optimizeForSpeed": true,
            }),
        )
        .await?;

    result["data"]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| "No screenshot data".into())
}

/// Get page text snapshot (accessibility-like).
pub async fn snapshot(conn: &Arc<CdpConnection>) -> Result<String, String> {
    let js = r#"
        (() => {
            const lines = [];
            const walk = (node, depth) => {
                if (node.nodeType === 3) {
                    const t = node.textContent.trim();
                    if (t) lines.push(t);
                    return;
                }
                if (node.nodeType !== 1) return;
                const el = node;
                const tag = el.tagName.toLowerCase();
                const style = getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden') return;
                
                if (tag === 'input' || tag === 'select' || tag === 'textarea') {
                    const type = el.type || tag;
                    const val = el.value || el.placeholder || '';
                    lines.push(`[${type}] ${val}`);
                    return;
                }
                if (tag === 'a') lines.push('[link] ');
                if (tag === 'button') lines.push('[button] ');
                if (tag === 'img') { lines.push(`[img] ${el.alt || ''}`); return; }
                
                for (const child of el.childNodes) walk(child, depth + 1);
            };
            walk(document.body, 0);
            return lines.join('\n');
        })()
    "#;
    evaluate(conn, js).await.map(|v| v.as_str().unwrap_or("").to_string())
}

/// Tap/click at coordinates.
pub async fn tap(conn: &Arc<CdpConnection>, x: f64, y: f64) -> Result<Value, String> {
    // Pipeline: mouseMoved + mousePressed + mouseReleased
    let results = conn
        .pipeline(vec![
            (
                "Input.dispatchMouseEvent",
                json!({"type": "mouseMoved", "x": x, "y": y}),
            ),
            (
                "Input.dispatchMouseEvent",
                json!({"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1}),
            ),
            (
                "Input.dispatchMouseEvent",
                json!({"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1}),
            ),
        ])
        .await;

    for r in &results {
        if let Err(e) = r {
            return Err(e.clone());
        }
    }

    Ok(json!({"success": true, "x": x, "y": y}))
}

/// Tap an element by text content. Finds element, gets coordinates, clicks.
/// Done in 2 CDP calls: 1 evaluate (find + coords) + 1 pipeline (mouse events).
pub async fn tap_text(conn: &Arc<CdpConnection>, text: &str) -> Result<Value, String> {
    let escaped = text.replace('\\', "\\\\").replace('\'', "\\'");
    let js = format!(
        r#"
        (() => {{
            const text = '{escaped}';
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let best = null;
            let bestLen = Infinity;
            while (walker.nextNode()) {{
                const n = walker.currentNode;
                const t = n.textContent.trim();
                if (t.includes(text) && t.length < bestLen) {{
                    best = n.parentElement;
                    bestLen = t.length;
                }}
            }}
            if (!best) return null;
            const r = best.getBoundingClientRect();
            if (r.width === 0 || r.height === 0) return null;
            return {{x: r.x + r.width/2, y: r.y + r.height/2}};
        }})()
    "#
    );

    let coords = evaluate(conn, &js).await?;
    if coords.is_null() {
        return Err(format!("Element with text '{text}' not found or not visible"));
    }

    let x = coords["x"].as_f64().ok_or("No x coordinate")?;
    let y = coords["y"].as_f64().ok_or("No y coordinate")?;
    tap(conn, x, y).await
}

/// Upload a file to an input element.
/// Uses single Runtime.evaluate with DataTransfer API + React/Vue event dispatch.
pub async fn upload_file(
    conn: &Arc<CdpConnection>,
    selector: &str,
    file_path: &Path,
) -> Result<Value, String> {
    // Read file
    let data = tokio::fs::read(file_path)
        .await
        .map_err(|e| format!("Read file: {e}"))?;
    let b64 = base64::engine::general_purpose::STANDARD.encode(&data);

    let filename = file_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("file");
    let mime = if filename.ends_with(".png") {
        "image/png"
    } else if filename.ends_with(".gif") {
        "image/gif"
    } else {
        "image/jpeg"
    };

    let escaped_sel = selector.replace('\\', "\\\\").replace('\'', "\\'");

    // Strategy 1: DataTransfer API (works for most frameworks)
    let js = format!(
        r#"
        (() => {{
            function deepQuery(sel, root) {{
                let el = root.querySelector(sel);
                if (el) return el;
                for (const n of root.querySelectorAll('*')) {{
                    if (n.shadowRoot) {{
                        el = deepQuery(sel, n.shadowRoot);
                        if (el) return el;
                    }}
                }}
                return null;
            }}
            
            const input = deepQuery('{escaped_sel}', document);
            if (!input) return {{error: 'Element not found: {escaped_sel}'}};
            
            // Decode base64 to File
            const b = atob('{b64}');
            const arr = new Uint8Array(b.length);
            for (let i = 0; i < b.length; i++) arr[i] = b.charCodeAt(i);
            const file = new File([arr], '{filename}', {{type: '{mime}'}});
            
            // Set via DataTransfer
            const dt = new DataTransfer();
            dt.items.add(file);
            input.files = dt.files;
            
            // Dispatch native events
            input.dispatchEvent(new Event('input', {{bubbles: true}}));
            input.dispatchEvent(new Event('change', {{bubbles: true}}));
            
            // React synthetic event
            const pk = Object.keys(input).find(k => k.startsWith('__reactProps'));
            if (pk && input[pk] && typeof input[pk].onChange === 'function') {{
                input[pk].onChange({{target: input, currentTarget: input}});
            }}
            
            // Vue v-model
            const vk = Object.keys(input).find(k => k.startsWith('__vue'));
            if (vk) {{
                input.dispatchEvent(new Event('input', {{bubbles: true}}));
            }}
            
            return {{
                success: true,
                files: input.files.length,
                fileName: input.files[0]?.name,
                method: 'dataTransfer'
            }};
        }})()
    "#
    );

    let result = evaluate(conn, &js).await?;

    if result.get("error").is_some() {
        return Err(result["error"].as_str().unwrap_or("unknown").to_string());
    }

    // If DataTransfer didn't trigger framework handler, fallback to
    // CDP setFileInputFiles + trusted click for file chooser interception
    if result.get("success").is_none() {
        return upload_file_cdp(conn, selector, file_path).await;
    }

    Ok(result)
}

/// Fallback: CDP-native file upload with file chooser interception.
async fn upload_file_cdp(
    conn: &Arc<CdpConnection>,
    selector: &str,
    file_path: &Path,
) -> Result<Value, String> {
    let path_str = file_path.to_str().ok_or("Invalid path")?;

    // Enable file chooser interception
    conn.call(
        "Page.setInterceptFileChooserDialog",
        json!({"enabled": true}),
    )
    .await?;

    let mut rx = conn.on_event("Page.fileChooserOpened");

    // Find visible parent and click it
    let escaped_sel = selector.replace('\\', "\\\\").replace('\'', "\\'");
    let coords = evaluate(
        conn,
        &format!(
            r#"
        (() => {{
            function deepQuery(sel, root) {{
                let el = root.querySelector(sel);
                if (el) return el;
                for (const n of root.querySelectorAll('*')) {{
                    if (n.shadowRoot) {{ el = deepQuery(sel, n.shadowRoot); if (el) return el; }}
                }}
                return null;
            }}
            const input = deepQuery('{escaped_sel}', document);
            if (!input) return null;
            let target = input.parentElement;
            while (target && (target.offsetWidth === 0 || target.offsetHeight === 0))
                target = target.parentElement;
            if (!target) return null;
            const r = target.getBoundingClientRect();
            return {{x: r.x + r.width/2, y: r.y + r.height/2}};
        }})()
    "#
        ),
    )
    .await?;

    if coords.is_null() {
        conn.remove_listeners("Page.fileChooserOpened");
        let _ = conn
            .call(
                "Page.setInterceptFileChooserDialog",
                json!({"enabled": false}),
            )
            .await;
        return Err("Could not find visible parent for file input".into());
    }

    let x = coords["x"].as_f64().unwrap();
    let y = coords["y"].as_f64().unwrap();

    // Hover + click
    tap(conn, x, y).await?;

    // Wait for file chooser event
    let event = tokio::select! {
        Some(e) = rx.recv() => Some(e),
        _ = tokio::time::sleep(std::time::Duration::from_secs(3)) => None,
    };

    conn.remove_listeners("Page.fileChooserOpened");

    if let Some(evt) = event {
        // Use backendNodeId from event if available
        if let Some(backend_id) = evt.get("backendNodeId").and_then(|v| v.as_u64()) {
            conn.call(
                "DOM.setFileInputFiles",
                json!({"backendNodeId": backend_id, "files": [path_str]}),
            )
            .await?;
        } else {
            // Resolve nodeId and set files
            let doc = conn.call("DOM.getDocument", json!({})).await?;
            let root_id = doc["root"]["nodeId"].as_u64().unwrap_or(0);
            let qr = conn
                .call(
                    "DOM.querySelector",
                    json!({"nodeId": root_id, "selector": selector}),
                )
                .await?;
            if let Some(node_id) = qr["nodeId"].as_u64() {
                conn.call(
                    "DOM.setFileInputFiles",
                    json!({"nodeId": node_id, "files": [path_str]}),
                )
                .await?;
            }
        }
    }

    let _ = conn
        .call(
            "Page.setInterceptFileChooserDialog",
            json!({"enabled": false}),
        )
        .await;

    Ok(json!({"success": true, "method": "fileChooser", "path": path_str}))
}

/// Get the page title.
pub async fn get_title(conn: &Arc<CdpConnection>) -> Result<String, String> {
    evaluate(conn, "document.title")
        .await
        .map(|v| v.as_str().unwrap_or("").to_string())
}

/// Press a key.
pub async fn press_key(conn: &Arc<CdpConnection>, key: &str) -> Result<Value, String> {
    let results = conn
        .pipeline(vec![
            (
                "Input.dispatchKeyEvent",
                json!({"type": "keyDown", "key": key}),
            ),
            (
                "Input.dispatchKeyEvent",
                json!({"type": "keyUp", "key": key}),
            ),
        ])
        .await;

    for r in &results {
        if let Err(e) = r {
            return Err(e.clone());
        }
    }
    Ok(json!({"success": true, "key": key}))
}

/// Scroll to an element by text.
pub async fn scroll_to(conn: &Arc<CdpConnection>, text: &str) -> Result<Value, String> {
    let escaped = text.replace('\\', "\\\\").replace('\'', "\\'");
    evaluate(
        conn,
        &format!(
            r#"
        (() => {{
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while (walker.nextNode()) {{
                if (walker.currentNode.textContent.includes('{escaped}')) {{
                    walker.currentNode.parentElement.scrollIntoView({{behavior:'smooth',block:'center'}});
                    return true;
                }}
            }}
            return false;
        }})()
    "#
        ),
    )
    .await
    .map(|v| json!({"scrolled": v}))
}
