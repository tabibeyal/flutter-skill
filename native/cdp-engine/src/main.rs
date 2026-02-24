mod cdp;
mod ops;
mod pool;
mod server;
mod workflow;

use pool::ConnectionPool;
use std::sync::Arc;

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();

    let mut cdp_port: u16 = 9222;
    let mut server_port: u16 = 4000;
    let mut connect_all = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--cdp-port" | "-c" => {
                i += 1;
                cdp_port = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(9222);
            }
            "--port" | "-p" => {
                i += 1;
                server_port = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(4000);
            }
            "--connect-all" => {
                connect_all = true;
            }
            "--help" | "-h" => {
                eprintln!("fs-cdp — High-performance CDP browser engine");
                eprintln!();
                eprintln!("Usage: fs-cdp [OPTIONS]");
                eprintln!();
                eprintln!("Options:");
                eprintln!("  -c, --cdp-port <PORT>   Chrome CDP port [default: 9222]");
                eprintln!("  -p, --port <PORT>        API server port [default: 4000]");
                eprintln!("  --connect-all            Pre-connect to all tabs on startup");
                eprintln!("  -h, --help               Show this help");
                return;
            }
            _ => {}
        }
        i += 1;
    }

    let pool = Arc::new(ConnectionPool::new(cdp_port));

    // Discover tabs
    match pool.discover_tabs().await {
        Ok(tabs) => {
            eprintln!("📡 Found {} tabs on CDP port {cdp_port}", tabs.len());
            for tab in &tabs {
                let url = if tab.url.len() > 60 {
                    format!("{}...", &tab.url[..57])
                } else {
                    tab.url.clone()
                };
                eprintln!("   📄 {} — {}", tab.id.get(..8).unwrap_or(&tab.id), url);
            }
        }
        Err(e) => {
            eprintln!("❌ Cannot connect to Chrome on port {cdp_port}: {e}");
            eprintln!("   Make sure Chrome is running with --remote-debugging-port={cdp_port}");
            std::process::exit(1);
        }
    }

    // Pre-connect to all tabs if requested
    if connect_all {
        let start = std::time::Instant::now();
        match pool.connect_all().await {
            Ok(n) => {
                eprintln!(
                    "✅ Connected to {n} tabs in {}ms",
                    start.elapsed().as_millis()
                );
            }
            Err(e) => eprintln!("⚠️ Error connecting: {e}"),
        }
    }

    // Start HTTP server
    if let Err(e) = server::start_http(pool, server_port).await {
        eprintln!("❌ Server error: {e}");
        std::process::exit(1);
    }
}
