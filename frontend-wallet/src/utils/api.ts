/**
 * Unauthority REST API Client with Timeout & Error Handling
 * REMOTE TESTNET READY - No more stuck loading!
 */

const API_TIMEOUT = 10000; // 10 seconds

interface FetchOptions extends RequestInit {
  timeout?: number;
}

async function fetchWithTimeout(
  url: string,
  options: FetchOptions = {}
): Promise<Response> {
  const { timeout = API_TIMEOUT, ...fetchOptions } = options;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);

  try {
    const response = await fetch(url, {
      ...fetchOptions,
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        ...fetchOptions.headers,
      },
    });
    clearTimeout(timeoutId);
    return response;
  } catch (error: any) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error('Request timeout - node may be offline');
    }
    throw error;
  }
}

export function getApiUrl(): string {
  // Check for manual override first
  const manualUrl = localStorage.getItem('uat_api_url_override');
  if (manualUrl) return manualUrl;
  
  // Use network-based configuration
  const savedNetwork = localStorage.getItem('uat_network') || 'testnet';
  const networks = {
    testnet: 'http://u3kilz7tv3ffhl2rafrzarbmiiojfcjz3eg527td5ocmibq44gj4htqd.onion',
    mainnet: 'http://uat-mainnet-pending.onion'
  };
  return networks[savedNetwork as keyof typeof networks] || networks.testnet;
}

export function setApiUrl(url: string): void {
  const normalized = url.replace(/\/+$/, '');
  localStorage.setItem('uat_api_url_override', normalized);
}

export const getApiBase = getApiUrl;
export const setApiBase = setApiUrl;
export const getApiBaseUrl = getApiUrl;

export async function healthCheck(): Promise<boolean> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/health`, {
      timeout: 5000,
    });
    return response.ok;
  } catch (error) {
    console.error('Health check failed:', error);
    return false;
  }
}

export async function checkNodeConnection(): Promise<boolean> {
  return healthCheck();
}

export async function getNodeInfo(): Promise<NodeInfo | null> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/node-info`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    console.error('Failed to get node info:', error);
    return null;
  }
}

export async function getBalance(address: string): Promise<number> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/balance/${address}`);
    if (!response.ok) {
      if (response.status === 404) return 0;
      throw new Error(`HTTP ${response.status}`);
    }
    const data = await response.json();
    return (data.balance || data.balance_uat || 0) / 100_000_000;
  } catch (error) {
    console.error('Failed to get balance:', error);
    return 0;
  }
}

export async function getHistory(address: string): Promise<Transaction[]> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/history/${address}`);
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : (data.transactions || []);
  } catch (error) {
    console.error('Failed to get history:', error);
    return [];
  }
}

export async function requestFaucet(address: string): Promise<FaucetResult> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/faucet`, {
      method: 'POST',
      body: JSON.stringify({ address }),
    });

    const data = await response.json();

    // Check data.status field - backend returns HTTP 200 with status:"error" for failures
    if (!response.ok || data.status === 'error') {
      return {
        success: false,
        message: data.message || data.msg || `Request failed: ${response.status}`,
      };
    }

    return {
      success: true,
      message: data.message || data.msg || 'Faucet claim successful',
      amount: data.amount,
      txHash: data.tx_hash,
    };
  } catch (error: any) {
    return {
      success: false,
      message: error.message || 'Network error',
    };
  }
}

export const claimFaucet = requestFaucet;

export async function sendTransaction(
  from: string,
  to: string,
  amount: number
): Promise<SendResult> {
  try {
    const microAmount = Math.floor(amount * 100_000_000);

    const response = await fetchWithTimeout(`${getApiUrl()}/send`, {
      method: 'POST',
      body: JSON.stringify({
        from,
        target: to,
        amount: microAmount,
      }),
    });

    const data = await response.json();

    // Check data.status field - backend returns HTTP 200 with status:"error" for failures
    if (!response.ok || data.status === 'error') {
      return {
        success: false,
        message: data.message || data.msg || `Send failed: ${response.status}`,
      };
    }

    return {
      success: true,
      txHash: data.tx_hash,
      message: data.message || data.msg || 'Transaction successful',
    };
  } catch (error: any) {
    return {
      success: false,
      message: error.message || 'Network error',
    };
  }
}

export async function getValidators(): Promise<Validator[]> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/validators`);
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : (data.validators || []);
  } catch (error) {
    console.error('Failed to get validators:', error);
    return [];
  }
}

export async function getLatestBlock(): Promise<Block | null> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/block`);
    if (!response.ok) return null;
    return await response.json();
  } catch (error) {
    console.error('Failed to get latest block:', error);
    return null;
  }
}

// Test connection to a specific endpoint
export async function testEndpoint(url: string): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    const normalizedUrl = url.replace(/\/+$/, '');
    const response = await fetchWithTimeout(`${normalizedUrl}/health`, {
      timeout: 8000,
    });

    if (response.ok) {
      const data = await response.json();
      return {
        success: true,
        message: `Connected successfully`,
        data,
      };
    } else {
      return {
        success: false,
        message: `HTTP Error: ${response.status}`,
      };
    }
  } catch (error: any) {
    return {
      success: false,
      message: error.message.includes('timeout') ? 'Connection timeout' : 'Network error',
    };
  }
}

// Submit burn transaction (Proof-of-burn: ETH/BTC -> UAT)
export async function submitBurn(request: BurnRequest): Promise<BurnResponse> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/burn`, {
      method: 'POST',
      body: JSON.stringify(request),
    });

    const data = await response.json();

    // Check data.status field - backend returns HTTP 200 with status:"error" for failures
    if (!response.ok || data.status === 'error') {
      return {
        status: 'error',
        error: data.message || data.msg || data.error || `Burn failed: ${response.status}`,
      };
    }

    return {
      status: 'success',
      ...data,
    };
  } catch (error: any) {
    return {
      status: 'error',
      error: error.message || 'Network error',
    };
  }
}

// Types
export interface NodeInfo {
  chain_id: string;
  node_address?: string;
  block_height: number;
  peers_count?: number;
  peer_count?: number;
  is_validator?: boolean;
  network?: string;
  chain_name?: string;
  eth_price_usd?: number;
  btc_price_usd?: number;
}

export interface Transaction {
  hash: string;
  from: string;
  to: string;
  amount: number;
  timestamp: number;
  tx_type: string;
  type?: string;
}

export interface FaucetResult {
  success: boolean;
  message: string;
  amount?: number;
  txHash?: string;
  status?: string;
  amount_uat?: number;
  error?: string;
  msg?: string;
}

export interface SendResult {
  success: boolean;
  message: string;
  txHash?: string;
}

export interface Validator {
  address: string;
  stake: number;
  voting_power?: number;
  is_active: boolean;
}

export interface Block {
  height: number;
  hash: string;
  prev_hash?: string;
  timestamp: number;
  transactions?: Transaction[];
}

export interface BurnRequest {
  asset: string;
  coin_type: string;
  amount: number;
  txid: string;
  proof: string;
  uat_address: string;
  recipient_address: string;
}

export interface BurnResponse {
  status: string;
  error?: string;
  tx_hash?: string;
  amount_uat?: number;
}
