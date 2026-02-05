use tokio::net::{TcpListener, TcpStream};
use tokio_tungstenite::{accept_async, tungstenite::Message};
use futures_util::{StreamExt, SinkExt};
use uat_core::websocket::{WsEvent, WsSubscriptionManager};
use std::sync::Arc;
use serde_json;

/// WebSocket server for real-time updates
pub async fn start_websocket_server(
    port: u16,
    subscription_manager: Arc<WsSubscriptionManager>,
) -> Result<(), Box<dyn std::error::Error>> {
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;

    println!("🔌 WebSocket server listening on ws://{}", addr);

    while let Ok((stream, peer_addr)) = listener.accept().await {
        let manager = subscription_manager.clone();
        tokio::spawn(handle_connection(stream, peer_addr.to_string(), manager));
    }

    Ok(())
}

async fn handle_connection(
    stream: TcpStream,
    client_id: String,
    manager: Arc<WsSubscriptionManager>,
) {
    let ws_stream = match accept_async(stream).await {
        Ok(ws) => ws,
        Err(e) => {
            eprintln!("WebSocket handshake error: {}", e);
            return;
        }
    };

    println!("✅ WebSocket client connected: {}", client_id);

    let (mut write, mut read) = ws_stream.split();
    let mut rx = manager.subscribe(client_id.clone()).await;

    // Spawn task to send events to client
    let client_id_clone = client_id.clone();
    let send_task = tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            let json = serde_json::to_string(&event).unwrap_or_default();
            let msg = Message::Text(json);

            if write.send(msg).await.is_err() {
                break;
            }
        }
    });

    // Handle incoming messages from client
    let receive_task = tokio::spawn(async move {
        while let Some(msg) = read.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    // Parse client requests (e.g., subscribe to specific events)
                    println!("📥 Received from {}: {}", client_id, text);
                }
                Ok(Message::Close(_)) => {
                    println!("🔌 Client disconnected: {}", client_id);
                    break;
                }
                Err(e) => {
                    eprintln!("WebSocket error: {}", e);
                    break;
                }
                _ => {}
            }
        }
    });

    // Wait for either task to complete
    tokio::select! {
        _ = send_task => {},
        _ = receive_task => {},
    }

    // Unsubscribe client
    manager.unsubscribe(&client_id_clone).await;
    println!("👋 Client {} disconnected", client_id_clone);
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio_tungstenite::connect_async;

    #[tokio::test]
    async fn test_websocket_connection() {
        let manager = Arc::new(WsSubscriptionManager::new());
        let manager_clone = manager.clone();

        // Start server
        tokio::spawn(async move {
            start_websocket_server(9001, manager_clone).await.unwrap();
        });

        // Give server time to start
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        // Connect client
        let (ws_stream, _) = connect_async("ws://127.0.0.1:9001").await.unwrap();
        
        // Broadcast event
        manager.broadcast(WsEvent::NewBlock {
            hash: "test123".to_string(),
            height: 100,
            transactions: 5,
            timestamp: 1234567890,
        }).await;

        drop(ws_stream);
    }
}
