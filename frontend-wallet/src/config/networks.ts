// Network Configuration for LOS Wallet
// Supports both Testnet and Mainnet in one app

export interface Network {
  id: string;
  name: string;
  chainId: string;
  rpcUrl: string;
  explorerUrl?: string;
  faucetEnabled: boolean;
  description: string;
}

export const NETWORKS: Record<string, Network> = {
  testnet: {
    id: 'testnet',
    name: 'LOS Testnet',
    chainId: 'los-testnet',
    rpcUrl: 'http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion',
    explorerUrl: 'http://ll22j45prmu3oymratallztx74peen4gsxudzbgf5qvybezobitvywyd.onion/explorer',
    faucetEnabled: true,
    description: 'Remote testnet via Tor hidden service'
  },
  mainnet: {
    id: 'mainnet',
    name: 'LOS Mainnet',
    chainId: 'los-mainnet',
    rpcUrl: 'http://los-mainnet-pending.onion',
    explorerUrl: 'http://los-mainnet-pending.onion/explorer',
    faucetEnabled: false,
    description: 'Mainnet via Tor hidden service (coming Q2 2026)'
  }
};

export const DEFAULT_NETWORK = 'testnet';

// Get network from localStorage or default
export function getCurrentNetwork(): Network {
  const savedNetwork = localStorage.getItem('los_network');
  return NETWORKS[savedNetwork || DEFAULT_NETWORK] || NETWORKS.testnet;
}

// Save network preference
export function setCurrentNetwork(networkId: string): void {
  if (NETWORKS[networkId]) {
    localStorage.setItem('los_network', networkId);
  }
}

// Verify network by querying /node-info
export async function verifyNetwork(rpcUrl: string): Promise<boolean> {
  try {
    const response = await fetch(`${rpcUrl}/node-info`);
    const data = await response.json();
    return !!data.chain_id;
  } catch (error) {
    console.error('Network verification failed:', error);
    return false;
  }
}
