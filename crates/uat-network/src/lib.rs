use libp2p::{
    futures::StreamExt,
    gossipsub, mdns, noise,
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux,
};
use std::error::Error;
use std::time::Duration;
use tokio::sync::mpsc;

#[derive(Debug)]
pub enum NetworkEvent {
    NewBlock(String),
    PeerDiscovered(String),
}

#[derive(NetworkBehaviour)]
pub struct UatBehaviour {
    pub gossipsub: gossipsub::Behaviour,
    pub mdns: mdns::tokio::Behaviour,
}

pub struct UatNode;

impl UatNode {
    pub async fn start(
        tx: mpsc::Sender<NetworkEvent>, 
        mut rx_out: mpsc::Receiver<String> 
    ) -> Result<(), Box<dyn Error>> {
        
        let mut swarm = libp2p::SwarmBuilder::with_new_identity()
            .with_tokio()
            .with_tcp(
                tcp::Config::default(),
                noise::Config::new,
                yamux::Config::default,
            )?
            .with_behaviour(|key| {
                let message_id_fn = |message: &gossipsub::Message| {
                    let mut s = std::collections::hash_map::DefaultHasher::new();
                    std::hash::Hash::hash(&message.data, &mut s);
                    gossipsub::MessageId::from(std::hash::Hasher::finish(&s).to_string())
                };

                let gossipsub_config = gossipsub::ConfigBuilder::default()
                    .heartbeat_interval(Duration::from_secs(1)) 
                    .validation_mode(gossipsub::ValidationMode::Strict)
                    .message_id_fn(message_id_fn)
                    .build()
                    .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

                let gossipsub = gossipsub::Behaviour::new(
                    gossipsub::MessageAuthenticity::Signed(key.clone()),
                    gossipsub_config,
                )?;

                let mdns = mdns::tokio::Behaviour::new(mdns::Config::default(), key.public().to_peer_id())?;

                Ok(UatBehaviour { gossipsub, mdns })
            })?
            .build();

        let topic = gossipsub::IdentTopic::new("uat-blocks");
        swarm.behaviour_mut().gossipsub.subscribe(&topic)?;

        swarm.listen_on("/ip4/0.0.0.0/tcp/0".parse()?)?;

        loop {
            tokio::select! {
                Some(msg_to_send) = rx_out.recv() => {
                    if msg_to_send.starts_with("DIAL:") {
                        let addr_str = &msg_to_send[5..];
                        if let Ok(maddr) = addr_str.parse::<libp2p::Multiaddr>() {
                            println!("📡 Swarm: Dialing {}...", maddr);
                            let _ = swarm.dial(maddr);
                        }
                    } else {
                        if let Err(e) = swarm.behaviour_mut().gossipsub.publish(topic.clone(), msg_to_send.as_bytes()) {
                            if !format!("{:?}", e).contains("InsufficientPeers") {
                                eprintln!("⚠️ Broadcast Error: {:?}", e);
                            }
                        }
                    }
                },
                event = swarm.select_next_some() => match event {
                    SwarmEvent::Behaviour(UatBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
                        for (peer_id, _addr) in list {
                            swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer_id);
                            let _ = tx.send(NetworkEvent::PeerDiscovered(peer_id.to_string())).await;
                        }
                    },
                    SwarmEvent::Behaviour(UatBehaviourEvent::Gossipsub(gossipsub::Event::Message { message, .. })) => {
                        let content = String::from_utf8_lossy(&message.data).to_string();
                        let _ = tx.send(NetworkEvent::NewBlock(content)).await;
                    },
                    SwarmEvent::NewListenAddr { address, .. } => {
                        println!("📍 Node mendengarkan di: {:?}", address);
                    },
                    SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                        println!("🤝 Connected to: {:?}", peer_id);
                    },
                    _ => {}
                }
            }
        }
    }
}