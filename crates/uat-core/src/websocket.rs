use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock};

/// WebSocket event types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "type", content = "data")]
pub enum WsEvent {
    /// New block created
    NewBlock {
        hash: String,
        height: u64,
        transactions: usize,
        timestamp: u64,
    },
    /// New transaction in mempool
    NewTransaction {
        hash: String,
        from: String,
        to: String,
        amount: u128,
    },
    /// Balance update
    BalanceUpdate {
        address: String,
        balance: u128,
    },
    /// Validator joined
    ValidatorJoined {
        address: String,
        stake: u128,
    },
    /// Validator left
    ValidatorLeft {
        address: String,
    },
    /// Network statistics
    NetworkStats {
        block_height: u64,
        tx_count: u64,
        validator_count: usize,
        peers: usize,
    },
}

/// WebSocket subscription manager
pub struct WsSubscriptionManager {
    /// Active subscriptions by client ID
    subscriptions: Arc<RwLock<HashMap<String, mpsc::UnboundedSender<WsEvent>>>>,
}

impl WsSubscriptionManager {
    pub fn new() -> Self {
        Self {
            subscriptions: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Subscribe a new client
    pub async fn subscribe(&self, client_id: String) -> mpsc::UnboundedReceiver<WsEvent> {
        let (tx, rx) = mpsc::unbounded_channel();
        self.subscriptions.write().await.insert(client_id, tx);
        rx
    }

    /// Unsubscribe a client
    pub async fn unsubscribe(&self, client_id: &str) {
        self.subscriptions.write().await.remove(client_id);
    }

    /// Broadcast event to all subscribers
    pub async fn broadcast(&self, event: WsEvent) {
        let subs = self.subscriptions.read().await;
        for (client_id, tx) in subs.iter() {
            if let Err(e) = tx.send(event.clone()) {
                eprintln!("Failed to send to client {}: {}", client_id, e);
            }
        }
    }

    /// Send event to specific client
    pub async fn send_to(&self, client_id: &str, event: WsEvent) -> Result<(), String> {
        let subs = self.subscriptions.read().await;
        if let Some(tx) = subs.get(client_id) {
            tx.send(event)
                .map_err(|e| format!("Failed to send: {}", e))?;
            Ok(())
        } else {
            Err("Client not found".to_string())
        }
    }

    /// Get subscriber count
    pub async fn subscriber_count(&self) -> usize {
        self.subscriptions.read().await.len()
    }
}

impl Default for WsSubscriptionManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_subscribe_unsubscribe() {
        let manager = WsSubscriptionManager::new();

        let mut rx = manager.subscribe("client1".to_string()).await;
        assert_eq!(manager.subscriber_count().await, 1);

        manager.unsubscribe("client1").await;
        assert_eq!(manager.subscriber_count().await, 0);
    }

    #[tokio::test]
    async fn test_broadcast() {
        let manager = WsSubscriptionManager::new();

        let mut rx1 = manager.subscribe("client1".to_string()).await;
        let mut rx2 = manager.subscribe("client2".to_string()).await;

        let event = WsEvent::NewBlock {
            hash: "block123".to_string(),
            height: 100,
            transactions: 5,
            timestamp: 1234567890,
        };

        manager.broadcast(event.clone()).await;

        assert_eq!(rx1.recv().await.unwrap(), event);
        assert_eq!(rx2.recv().await.unwrap(), event);
    }

    #[tokio::test]
    async fn test_send_to_specific_client() {
        let manager = WsSubscriptionManager::new();

        let mut rx1 = manager.subscribe("client1".to_string()).await;
        let mut rx2 = manager.subscribe("client2".to_string()).await;

        let event = WsEvent::BalanceUpdate {
            address: "UAT123".to_string(),
            balance: 1000,
        };

        manager.send_to("client1", event.clone()).await.unwrap();

        // Client 1 should receive the event
        assert_eq!(rx1.recv().await.unwrap(), event);

        // Client 2 should not receive anything
        assert!(rx2.try_recv().is_err());
    }
}
