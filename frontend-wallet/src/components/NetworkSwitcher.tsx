import { useState, useEffect } from 'react';
import { NETWORKS, getCurrentNetwork, setCurrentNetwork, verifyNetwork } from '../config/networks';

interface NetworkSwitcherProps {
  onNetworkChange?: (networkId: string) => void;
}

export default function NetworkSwitcher({ onNetworkChange }: NetworkSwitcherProps) {
  const [currentNetwork, setNetwork] = useState(getCurrentNetwork());
  const [connectionStatus, setConnectionStatus] = useState<'online' | 'offline' | 'checking'>('checking');

  useEffect(() => {
    checkConnection();
  }, [currentNetwork]);

  const checkConnection = async () => {
    setConnectionStatus('checking');
    const isOnline = await verifyNetwork(currentNetwork.rpcUrl);
    setConnectionStatus(isOnline ? 'online' : 'offline');
  };

  const handleNetworkChange = (networkId: string) => {
    const network = NETWORKS[networkId];
    if (network) {
      setNetwork(network);
      setCurrentNetwork(networkId);
      onNetworkChange?.(networkId);
    }
  };

  const getStatusColor = () => {
    switch (connectionStatus) {
      case 'online': return '#10b981';
      case 'offline': return '#ef4444';
      case 'checking': return '#f59e0b';
    }
  };

  const getStatusText = () => {
    switch (connectionStatus) {
      case 'online': return '🟢';
      case 'offline': return '🔴';
      case 'checking': return '🟡';
    }
  };

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
      <span style={{ fontSize: '14px', color: getStatusColor() }}>
        {getStatusText()}
      </span>
      <select
        value={currentNetwork.id}
        onChange={(e) => handleNetworkChange(e.target.value)}
        style={{
          padding: '6px 10px',
          backgroundColor: '#1a1a24',
          border: '1px solid #374151',
          borderRadius: '6px',
          color: '#ffffff',
          fontSize: '13px',
          cursor: 'pointer',
          outline: 'none',
          fontWeight: '500'
        }}
      >
        {Object.values(NETWORKS).map((network) => (
          <option key={network.id} value={network.id}>
            {network.name}
          </option>
        ))}
      </select>
    </div>
  );
}
