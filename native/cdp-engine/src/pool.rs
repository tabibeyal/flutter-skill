//! Connection pool — maintains persistent CDP connections to all browser tabs.

use crate::cdp::CdpConnection;
use dashmap::DashMap;
use std::sync::Arc;

/// Manages multiple tab connections.
pub struct ConnectionPool {
    port: u16,
    /// tab_id -> CdpConnection
    tabs: DashMap<String, Arc<CdpConnection>>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct TabInfo {
    pub id: String,
    pub url: String,
    pub title: String,
    #[serde(rename = "webSocketDebuggerUrl")]
    pub ws_url: String,
    #[serde(rename = "type")]
    pub tab_type: String,
}

impl ConnectionPool {
    pub fn new(port: u16) -> Self {
        Self {
            port,
            tabs: DashMap::new(),
        }
    }

    /// Discover all page tabs from Chrome's JSON endpoint.
    pub async fn discover_tabs(&self) -> Result<Vec<TabInfo>, String> {
        let url = format!("http://127.0.0.1:{}/json", self.port);
        let body = reqwest_get(&url).await?;
        let tabs: Vec<TabInfo> =
            serde_json::from_str(&body).map_err(|e| format!("JSON parse: {e}"))?;
        Ok(tabs
            .into_iter()
            .filter(|t| t.tab_type == "page")
            .collect())
    }

    /// Get or create a connection to a tab by ID.
    pub async fn get_or_connect(&self, tab_id: &str) -> Result<Arc<CdpConnection>, String> {
        if let Some(conn) = self.tabs.get(tab_id) {
            return Ok(conn.value().clone());
        }

        // Find the tab's WS URL
        let tabs = self.discover_tabs().await?;
        let tab = tabs
            .iter()
            .find(|t| t.id == tab_id)
            .ok_or_else(|| format!("Tab {tab_id} not found"))?;

        let conn = CdpConnection::connect(&tab.ws_url).await?;

        // Enable required domains
        let _ = conn
            .pipeline(vec![
                ("Page.enable", serde_json::json!({})),
                ("DOM.enable", serde_json::json!({})),
                ("Runtime.enable", serde_json::json!({})),
            ])
            .await;

        self.tabs.insert(tab_id.to_string(), conn.clone());
        Ok(conn)
    }

    /// Find a tab by URL (prefix match) and connect to it.
    pub async fn get_by_url(&self, url: &str) -> Result<(String, Arc<CdpConnection>), String> {
        let tabs = self.discover_tabs().await?;

        // Exact match first
        if let Some(tab) = tabs.iter().find(|t| t.url == url) {
            let conn = self.get_or_connect(&tab.id).await?;
            return Ok((tab.id.clone(), conn));
        }

        // Origin match
        let origin = extract_origin(url);
        if let Some(tab) = tabs.iter().find(|t| t.url.starts_with(&origin)) {
            let conn = self.get_or_connect(&tab.id).await?;
            return Ok((tab.id.clone(), conn));
        }

        Err(format!("No tab found for URL: {url}"))
    }

    /// Connect to all page tabs.
    pub async fn connect_all(&self) -> Result<usize, String> {
        let tabs = self.discover_tabs().await?;
        let mut count = 0;
        for tab in &tabs {
            if self.get_or_connect(&tab.id).await.is_ok() {
                count += 1;
            }
        }
        Ok(count)
    }

    /// Get a connection by tab ID (must already be connected).
    pub fn get(&self, tab_id: &str) -> Option<Arc<CdpConnection>> {
        self.tabs.get(tab_id).map(|v| v.value().clone())
    }

    /// List all connected tab IDs.
    pub fn connected_tabs(&self) -> Vec<String> {
        self.tabs.iter().map(|e| e.key().clone()).collect()
    }

    /// Close a tab by ID.
    pub async fn close_tab(&self, tab_id: &str) -> Result<(), String> {
        self.tabs.remove(tab_id);
        let url = format!("http://127.0.0.1:{}/json/close/{}", self.port, tab_id);
        let _ = reqwest_get(&url).await;
        Ok(())
    }
}

fn extract_origin(url: &str) -> String {
    if let Some(pos) = url.find("://") {
        if let Some(end) = url[pos + 3..].find('/') {
            return url[..pos + 3 + end].to_string();
        }
    }
    url.to_string()
}

/// Minimal HTTP GET using raw TCP with Content-Length parsing.
async fn reqwest_get(url: &str) -> Result<String, String> {
    use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};

    let url_str = url.strip_prefix("http://").unwrap_or(url);
    let (host_port, path) = url_str.split_once('/').unwrap_or((url_str, ""));
    let path = format!("/{path}");

    let stream = tokio::net::TcpStream::connect(host_port)
        .await
        .map_err(|e| format!("Connect {host_port}: {e}"))?;

    let (reader, mut writer) = stream.into_split();
    let req = format!("GET {path} HTTP/1.1\r\nHost: {host_port}\r\nConnection: close\r\n\r\n");
    writer
        .write_all(req.as_bytes())
        .await
        .map_err(|e| format!("Write: {e}"))?;

    let mut reader = BufReader::new(reader);
    let mut content_length: usize = 0;

    // Read headers
    loop {
        let mut line = String::new();
        reader
            .read_line(&mut line)
            .await
            .map_err(|e| format!("Read header: {e}"))?;
        let trimmed = line.trim();
        if trimmed.is_empty() {
            break;
        }
        if let Some(val) = trimmed.strip_prefix("Content-Length:") {
            content_length = val.trim().parse().unwrap_or(0);
        }
        if let Some(val) = trimmed.strip_prefix("content-length:") {
            content_length = val.trim().parse().unwrap_or(0);
        }
    }

    if content_length == 0 {
        // Fallback: read with timeout
        let mut buf = Vec::with_capacity(65536);
        let _ = tokio::time::timeout(
            std::time::Duration::from_secs(2),
            reader.read_to_end(&mut buf),
        )
        .await;
        return String::from_utf8(buf).map_err(|e| format!("UTF8: {e}"));
    }

    // Read exact body
    let mut body = vec![0u8; content_length];
    reader
        .read_exact(&mut body)
        .await
        .map_err(|e| format!("Read body: {e}"))?;

    String::from_utf8(body).map_err(|e| format!("UTF8: {e}"))
}
