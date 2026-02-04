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
    rpcUrl: 'http://localhost:3030',
    explorerUrl: 'http://localhost:3030/explorer',
    faucetEnabled: true,
    description: 'Local testnet for development and testing'
  },
  mainnet: {
    id: 'mainnet',
    name: 'UAT Mainnet',
    chainId: 'uat-mainnet',
    rpcUrl: 'https://rpc.unauthority.io',
    explorerUrl: 'https://explorer.unauthority.io',
    faucetEnabled: false,
    description: 'Production network with real UAT tokens'
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
