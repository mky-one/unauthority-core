// Network Switcher Component for UAT Wallet
import { useState, useEffect } from 'react';
import { NETWORKS, getCurrentNetwork, setCurrentNetwork, verifyNetwork } from '../config/networks';

interface NetworkSwitcherProps {
  onNetworkChange?: (networkId: string) => void;
}

export default function NetworkSwitcher({ onNetworkChange }: NetworkSwitcherProps) {
  const [currentNetwork, setNetwork] = useState(getCurrentNetwork());
  const [isVerifying, setIsVerifying] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<'online' | 'offline' | 'checking'>('checking');

  useEffect(() => {
    checkConnection();
  }, [currentNetwork]);

  const checkConnection = async () => {
    setIsVerifying(true);
    setConnectionStatus('checking');
    
    const isOnline = await verifyNetwork(currentNetwork.rpcUrl);
    setConnectionStatus(isOnline ? 'online' : 'offline');
    setIsVerifying(false);
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
      case 'online': return '#10b981'; // green
      case 'offline': return '#ef4444'; // red
      case 'checking': return '#f59e0b'; // orange
    }
  };

  const getStatusText = () => {
    switch (connectionStatus) {
      case 'online': return '🟢 Connected';
      case 'offline': return '🔴 Offline';
      case 'checking': return '🟡 Checking...';
    }
  };

  return (
    <div style={{
      padding: '16px',
      backgroundColor: '#1a1a24',
      borderRadius: '8px',
      marginBottom: '20px'
    }}>
      <div style={{ 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between',
        marginBottom: '12px'
      }}>
        <label style={{ 
          fontSize: '14px', 
          fontWeight: '600',
          color: '#9ca3af'
        }}>
          Network
        </label>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          fontSize: '12px',
          color: getStatusColor()
        }}>
          {getStatusText()}
        </div>
      </div>

      <select
        value={currentNetwork.id}
        onChange={(e) => handleNetworkChange(e.target.value)}
        disabled={isVerifying}
        style={{
          width: '100%',
          padding: '12px',
          backgroundColor: '#0a0a0f',
          border: '1px solid #374151',
          borderRadius: '6px',
          color: 'white',
          fontSize: '14px',
          cursor: 'pointer',
          outline: 'none'
        }}
      >
        {Object.values(NETWORKS).map((network) => (
          <option key={network.id} value={network.id}>
            {network.name} {network.faucetEnabled ? '(Testnet)' : '(Mainnet)'}
          </option>
        ))}
      </select>

      <div style={{
        marginTop: '12px',
        fontSize: '12px',
        color: '#6b7280'
      }}>
        <div>RPC: {currentNetwork.rpcUrl}</div>
        <div style={{ marginTop: '4px' }}>{currentNetwork.description}</div>
        {currentNetwork.faucetEnabled && (
          <div style={{ 
            marginTop: '8px',
            padding: '8px',
            backgroundColor: '#065f46',
            borderRadius: '4px',
            color: '#10b981'
          }}>
            💧 Faucet available: 100,000 UAT per request
          </div>
        )}
      </div>

      <button
        onClick={checkConnection}
        disabled={isVerifying}
        style={{
          marginTop: '12px',
          width: '100%',
          padding: '8px',
          backgroundColor: '#374151',
          border: 'none',
          borderRadius: '6px',
          color: 'white',
          fontSize: '13px',
          cursor: isVerifying ? 'not-allowed' : 'pointer',
          opacity: isVerifying ? 0.6 : 1
        }}
      >
        {isVerifying ? 'Checking...' : 'Test Connection'}
      </button>
    </div>
  );
}
