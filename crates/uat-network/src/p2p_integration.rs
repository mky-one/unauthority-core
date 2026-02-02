// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// UNAUTHORITY (UAT) - P2P NETWORK INTEGRATION
// 
// Integration layer for Noise Protocol-based secure node communication
// - Manages sentry and signer node lifecycle
// - Handles encrypted message routing
// - Monitors session health and connection state
// - Enforces security policies (IP whitelist, rate limiting)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};
use serde::{Serialize, Deserialize};
use std::time::{SystemTime, UNIX_EPOCH};

/// Re-export P2P encryption types
pub use crate::p2p_encryption::{
    NoiseProtocolManager,
    NoisePattern,
    NoiseSession,
    EncryptedMessage,
    NodeIdentity,
    NodeType,
    SentryNode,
    SignerNode,
    CipherKey,
};

/// Manages P2P network connectivity and security policies
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct P2PNetworkManager {
    /// Local node configuration
    pub local_node_id: String,
    pub local_node_type: NodeType,
    
    /// Noise Protocol manager for encryption
    pub noise_manager: Arc<Mutex<NoiseProtocolManager>>,
    
    /// Peer connection information
    pub peer_connections: HashMap<String, PeerConnection>,
    
    /// IP whitelist for additional security
    pub ip_whitelist: HashSet<String>,
    pub whitelist_enabled: bool,
    
    /// Connection rate limiter
    pub connection_limits: HashMap<String, ConnectionRateLimit>,
    pub rate_limit_enabled: bool,
    
    /// Message queue for routing
    pub outbound_queue: Vec<QueuedMessage>,
    pub inbound_queue: Vec<QueuedMessage>,
    
    /// Network statistics
    pub stats: NetworkStats,
    
    /// Enable/disable network enforcement
    pub enforcement_enabled: bool,
}

/// Peer connection metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerConnection {
    pub peer_id: String,
    pub remote_address: String,
    pub node_type: NodeType,
    pub session_id: Option<String>,
    pub is_connected: bool,
    pub last_message_time: u64,
    pub messages_sent: u64,
    pub messages_received: u64,
    pub connected_since: u64,
    pub connection_quality: f64, // 0.0-1.0
}

/// Rate limit tracking per peer
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionRateLimit {
    pub peer_id: String,
    pub message_count: u32,
    pub window_start_time: u64,
    pub max_messages_per_second: u32,
    pub is_throttled: bool,
}

/// Message queued for encryption and routing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueuedMessage {
    pub destination_peer_id: String,
    pub payload: Vec<u8>,
    pub priority: MessagePriority,
    pub queued_at: u64,
    pub requires_encryption: bool,
}

/// Message priority levels
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub enum MessagePriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3,
}

/// Network statistics for monitoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkStats {
    pub total_connections: u32,
    pub active_connections: u32,
    pub total_messages_sent: u64,
    pub total_messages_received: u64,
    pub total_bytes_sent: u64,
    pub total_bytes_received: u64,
    pub active_sessions: u32,
    pub failed_connections: u32,
    pub security_violations: u32,
}

impl P2PNetworkManager {
    /// Create new P2P network manager
    pub fn new(
        local_node_id: String,
        local_node_type: NodeType,
        local_static_key: Vec<u8>,
    ) -> Result<Self, String> {
        let noise_mgr = NoiseProtocolManager::new(
            local_node_id.clone(),
            local_static_key,
        )?;

        Ok(Self {
            local_node_id,
            local_node_type,
            noise_manager: Arc::new(Mutex::new(noise_mgr)),
            peer_connections: HashMap::new(),
            ip_whitelist: HashSet::new(),
            whitelist_enabled: false,
            connection_limits: HashMap::new(),
            rate_limit_enabled: false,
            outbound_queue: Vec::new(),
            inbound_queue: Vec::new(),
            stats: NetworkStats {
                total_connections: 0,
                active_connections: 0,
                total_messages_sent: 0,
                total_messages_received: 0,
                total_bytes_sent: 0,
                total_bytes_received: 0,
                active_sessions: 0,
                failed_connections: 0,
                security_violations: 0,
            },
            enforcement_enabled: true,
        })
    }

    /// Register a peer for connection
    pub fn add_peer(
        &mut self,
        peer_id: String,
        remote_address: String,
        node_type: NodeType,
    ) -> Result<(), String> {
        if self.peer_connections.contains_key(&peer_id) {
            return Err(format!("Peer {} already registered", peer_id));
        }

        // Check IP whitelist if enabled
        if self.whitelist_enabled && !self.ip_whitelist.contains(&remote_address) {
            self.stats.security_violations += 1;
            return Err(format!("IP {} not in whitelist", remote_address));
        }

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        self.peer_connections.insert(
            peer_id.clone(),
            PeerConnection {
                peer_id: peer_id.clone(),
                remote_address,
                node_type,
                session_id: None,
                is_connected: false,
                last_message_time: now,
                messages_sent: 0,
                messages_received: 0,
                connected_since: now,
                connection_quality: 1.0,
            },
        );

        self.stats.total_connections += 1;
        Ok(())
    }

    /// Remove a peer
    pub fn remove_peer(&mut self, peer_id: &str) -> Result<(), String> {
        if let Some(conn) = self.peer_connections.remove(peer_id) {
            if conn.is_connected {
                self.stats.active_connections = self.stats.active_connections.saturating_sub(1);
            }
            
            // Note: Noise session closed naturally when session_id removed from peer_connections
            
            Ok(())
        } else {
            Err(format!("Peer {} not found", peer_id))
        }
    }

    /// Establish encrypted session with peer
    pub fn connect_to_peer(&mut self, peer_id: &str) -> Result<String, String> {
        if let Some(peer) = self.peer_connections.get(peer_id).cloned() {
            if peer.is_connected {
                return Ok(peer.session_id.unwrap_or_default());
            }

            // Check rate limiting
            if self.rate_limit_enabled {
                if let Some(limit) = self.connection_limits.get(peer_id) {
                    if limit.is_throttled {
                        self.stats.security_violations += 1;
                        return Err(format!("Peer {} is rate limited", peer_id));
                    }
                }
            }

            // Initiate Noise Protocol handshake
            // Note: peer_static_key would come from peer discovery/bootstrap
            let peer_static_key = vec![0u8; 32]; // In real implementation, get from peer registry
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            
            let noise_result = {
                let mut mgr = self.noise_manager.lock()
                    .map_err(|e| format!("Failed to acquire noise lock: {}", e))?
                mgr.initiate_handshake(
                    peer_id.to_string(),
                    peer_static_key,
                    now,
                )
            };

            match noise_result {
                Ok(session_id) => {
                    // Update peer connection
                    if let Some(conn) = self.peer_connections.get_mut(peer_id) {
                        conn.session_id = Some(session_id.clone());
                        conn.is_connected = true;
                        self.stats.active_connections += 1;
                        self.stats.active_sessions = self.stats.active_sessions.saturating_add(1);
                    }
                    Ok(session_id)
                }
                Err(e) => {
                    self.stats.failed_connections += 1;
                    Err(format!("Handshake failed: {}", e))
                }
            }
        } else {
            Err(format!("Peer {} not registered", peer_id))
        }
    }

    /// Send encrypted message to peer
    pub fn send_message(
        &mut self,
        peer_id: &str,
        payload: Vec<u8>,
        priority: MessagePriority,
    ) -> Result<(), String> {
        if !self.enforcement_enabled {
            return Err("Network enforcement disabled".to_string());
        }

        if let Some(peer) = self.peer_connections.get(peer_id) {
            if !peer.is_connected {
                return Err(format!("Peer {} not connected", peer_id));
            }

            let session_id = peer.session_id
                .clone()
                .ok_or_else(|| "No active session".to_string())?;

            // Encrypt message
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            
            let noise_result = {
                let mut mgr = self.noise_manager.lock()
                    .map_err(|e| format!("Failed to acquire noise lock: {}", e))?
                mgr.encrypt_message(&session_id, &payload, now)
            };

            match noise_result {
                Ok(encrypted_msg) => {
                    let now = SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs();

                    // Queue message
                    self.outbound_queue.push(QueuedMessage {
                        destination_peer_id: peer_id.to_string(),
                        payload: encrypted_msg.ciphertext.clone(),
                        priority,
                        queued_at: now,
                        requires_encryption: false, // Already encrypted
                    });

                    // Update stats
                    if let Some(conn) = self.peer_connections.get_mut(peer_id) {
                        conn.messages_sent += 1;
                        conn.last_message_time = now;
                    }
                    self.stats.total_messages_sent += 1;
                    self.stats.total_bytes_sent += payload.len() as u64;

                    Ok(())
                }
                Err(e) => {
                    self.stats.security_violations += 1;
                    Err(format!("Encryption failed: {}", e))
                }
            }
        } else {
            Err(format!("Peer {} not found", peer_id))
        }
    }

    /// Receive and decrypt message from peer
    pub fn receive_message(
        &mut self,
        peer_id: &str,
        encrypted_payload: Vec<u8>,
    ) -> Result<Vec<u8>, String> {
        if let Some(peer) = self.peer_connections.get(peer_id) {
            if !peer.is_connected {
                return Err(format!("Peer {} not connected", peer_id));
            }

            let session_id = peer.session_id
                .clone()
                .ok_or_else(|| "No active session".to_string())?;

            // Decrypt message
            let encrypted_msg = EncryptedMessage {
                session_id: session_id.clone(),
                sequence_number: 0,
                ciphertext: encrypted_payload.clone(),
                mac_tag: vec![], // In real implementation, parse from wire format
                timestamp: SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs(),
            };
            
            let noise_result = {
                let mut mgr = self.noise_manager.lock()
                    .map_err(|e| format!("Failed to acquire noise lock: {}", e))?
                mgr.decrypt_message(&session_id, &encrypted_msg)
            };

            match noise_result {
                Ok(plaintext) => {
                    let now = SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs();

                    // Update stats
                    if let Some(conn) = self.peer_connections.get_mut(peer_id) {
                        conn.messages_received += 1;
                        conn.last_message_time = now;
                    }
                    self.stats.total_messages_received += 1;
                    self.stats.total_bytes_received += plaintext.len() as u64;

                    Ok(plaintext)
                }
                Err(e) => {
                    self.stats.security_violations += 1;
                    Err(format!("Decryption failed: {}", e))
                }
            }
        } else {
            Err(format!("Peer {} not found", peer_id))
        }
    }

    /// Add IP to whitelist
    pub fn add_ip_whitelist(&mut self, ip_addr: String) {
        self.ip_whitelist.insert(ip_addr);
    }

    /// Enable IP whitelist enforcement
    pub fn enable_ip_whitelist(&mut self) {
        self.whitelist_enabled = true;
    }

    /// Disable IP whitelist enforcement
    pub fn disable_ip_whitelist(&mut self) {
        self.whitelist_enabled = false;
    }

    /// Set rate limit for peer
    pub fn set_rate_limit(
        &mut self,
        peer_id: String,
        max_messages_per_second: u32,
    ) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        self.connection_limits.insert(
            peer_id.clone(),
            ConnectionRateLimit {
                peer_id,
                message_count: 0,
                window_start_time: now,
                max_messages_per_second,
                is_throttled: false,
            },
        );
    }

    /// Enable rate limiting
    pub fn enable_rate_limiting(&mut self) {
        self.rate_limit_enabled = true;
    }

    /// Disable rate limiting
    pub fn disable_rate_limiting(&mut self) {
        self.rate_limit_enabled = false;
    }

    /// Check and update rate limits (call periodically)
    pub fn update_rate_limits(&mut self) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        for limit in self.connection_limits.values_mut() {
            // Reset window every second
            if now > limit.window_start_time {
                limit.message_count = 0;
                limit.window_start_time = now;
                limit.is_throttled = false;
            }
        }
    }

    /// Get peer connection info
    pub fn get_peer(&self, peer_id: &str) -> Option<&PeerConnection> {
        self.peer_connections.get(peer_id)
    }

    /// Get all active peers
    pub fn get_active_peers(&self) -> Vec<String> {
        self.peer_connections
            .iter()
            .filter(|(_, conn)| conn.is_connected)
            .map(|(id, _)| id.clone())
            .collect()
    }

    /// Get all registered peers
    pub fn get_all_peers(&self) -> Vec<String> {
        self.peer_connections.keys().cloned().collect()
    }

    /// Process outbound message queue
    pub fn flush_outbound_queue(&mut self) -> Vec<QueuedMessage> {
        // Sort by priority (critical first)
        self.outbound_queue.sort_by(|a, b| b.priority.cmp(&a.priority));
        
        let queue = self.outbound_queue.drain(..).collect();
        queue
    }

    /// Process inbound message queue
    pub fn flush_inbound_queue(&mut self) -> Vec<QueuedMessage> {
        let queue = self.inbound_queue.drain(..).collect();
        queue
    }

    /// Get network statistics
    pub fn get_statistics(&self) -> NetworkStats {
        self.stats.clone()
    }

    /// Close connection to peer
    pub fn disconnect_peer(&mut self, peer_id: &str) -> Result<(), String> {
        if let Some(conn) = self.peer_connections.get_mut(peer_id) {
            conn.is_connected = false;
            
            if self.stats.active_connections > 0 {
                self.stats.active_connections -= 1;
            }
            
            Ok(())
        } else {
            Err(format!("Peer {} not found", peer_id))
        }
    }

    /// Emergency disable enforcement
    pub fn disable_enforcement(&mut self) {
        self.enforcement_enabled = false;
    }

    /// Re-enable enforcement
    pub fn enable_enforcement(&mut self) {
        self.enforcement_enabled = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_p2p_manager() {
        let key = vec![0u8; 32];
        let mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        );
        
        assert!(mgr.is_ok());
    }

    #[test]
    fn test_add_peer() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        let result = mgr.add_peer(
            "node2".to_string(),
            "127.0.0.1:30334".to_string(),
            NodeType::Signer,
        );

        assert!(result.is_ok());
        assert!(mgr.peer_connections.contains_key("node2"));
    }

    #[test]
    fn test_remove_peer() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.add_peer(
            "node2".to_string(),
            "127.0.0.1:30334".to_string(),
            NodeType::Signer,
        ).unwrap();

        let result = mgr.remove_peer("node2");
        assert!(result.is_ok());
        assert!(!mgr.peer_connections.contains_key("node2"));
    }

    #[test]
    fn test_ip_whitelist() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.enable_ip_whitelist();
        mgr.add_ip_whitelist("127.0.0.1".to_string());

        let result = mgr.add_peer(
            "node2".to_string(),
            "127.0.0.1:30334".to_string(),
            NodeType::Signer,
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_ip_whitelist_rejection() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.enable_ip_whitelist();

        let result = mgr.add_peer(
            "node2".to_string(),
            "192.168.1.1:30334".to_string(),
            NodeType::Signer,
        );

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not in whitelist"));
    }

    #[test]
    fn test_get_active_peers() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.add_peer(
            "node2".to_string(),
            "127.0.0.1:30334".to_string(),
            NodeType::Signer,
        ).unwrap();

        mgr.add_peer(
            "node3".to_string(),
            "127.0.0.1:30335".to_string(),
            NodeType::Signer,
        ).unwrap();

        let active = mgr.get_active_peers();
        assert_eq!(active.len(), 0); // None connected yet
        
        let all = mgr.get_all_peers();
        assert_eq!(all.len(), 2);
    }

    #[test]
    fn test_rate_limiting() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.enable_rate_limiting();
        mgr.set_rate_limit("node2".to_string(), 100);

        assert!(mgr.connection_limits.contains_key("node2"));
    }

    #[test]
    fn test_statistics() {
        let key = vec![0u8; 32];
        let mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        let stats = mgr.get_statistics();
        assert_eq!(stats.total_connections, 0);
        assert_eq!(stats.active_connections, 0);
        assert_eq!(stats.total_messages_sent, 0);
    }

    #[test]
    fn test_message_queue_priority() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.outbound_queue.push(QueuedMessage {
            destination_peer_id: "node2".to_string(),
            payload: vec![1, 2, 3],
            priority: MessagePriority::Low,
            queued_at: 0,
            requires_encryption: true,
        });

        mgr.outbound_queue.push(QueuedMessage {
            destination_peer_id: "node3".to_string(),
            payload: vec![4, 5, 6],
            priority: MessagePriority::Critical,
            queued_at: 0,
            requires_encryption: true,
        });

        let queue = mgr.flush_outbound_queue();
        assert_eq!(queue.len(), 2);
        assert_eq!(queue[0].priority, MessagePriority::Critical);
        assert_eq!(queue[1].priority, MessagePriority::Low);
    }

    #[test]
    fn test_enforcement_disable() {
        let key = vec![0u8; 32];
        let mut mgr = P2PNetworkManager::new(
            "node1".to_string(),
            NodeType::Sentry,
            key,
        ).unwrap();

        mgr.disable_enforcement();
        assert!(!mgr.enforcement_enabled);

        mgr.enable_enforcement();
        assert!(mgr.enforcement_enabled);
    }
}
