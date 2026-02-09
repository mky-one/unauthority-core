// Network Configuration for UAT Wallet
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
    name: 'UAT Testnet',
    chainId: 'uat-testnet',
    rpcUrl: 'http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion',
    explorerUrl: 'http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion/explorer',
    faucetEnabled: true,
    description: 'Remote testnet via Tor hidden service'
  },
  mainnet: {
    id: 'mainnet',
    name: 'UAT Mainnet',
    chainId: 'uat-mainnet',
    rpcUrl: 'http://uat-mainnet-pending.onion',
    explorerUrl: 'http://uat-mainnet-pending.onion/explorer',
    faucetEnabled: false,
    description: 'Mainnet via Tor hidden service (coming Q2 2026)'
  }
};

export const DEFAULT_NETWORK = 'testnet';

// Get network from localStorage or default
export function getCurrentNetwork(): Network {
  const savedNetwork = localStorage.getItem('uat_network');
  return NETWORKS[savedNetwork || DEFAULT_NETWORK] || NETWORKS.testnet;
}

// Save network preference
export function setCurrentNetwork(networkId: string): void {
  if (NETWORKS[networkId]) {
    localStorage.setItem('uat_network', networkId);
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
