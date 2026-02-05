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
  return localStorage.getItem('uat_api_url') || 'http://localhost:3030';
}

export function setApiUrl(url: string): void {
  const normalized = url.replace(/\/+$/, '');
  localStorage.setItem('uat_api_url', normalized);
}

export const getApiBase = getApiUrl;
export const setApiBase = setApiUrl;
export const getApiBaseUrl = getApiUrl;

// Type definitions
export interface Balance {
  balance_void: number;
  balance_uat: number;
  address: string;
}

export interface NodeInfo {
  node_address: string;
  network_id: number;
  chain_name: string;
  total_supply_void: number;
  remaining_supply_void: number;
  total_burned_idr: number;
  validator_count: number;
  block_height: number;
  peer_count: number;
  eth_price_usd?: number;
  btc_price_usd?: number;
}

export interface SendRequest {
  from?: string;
  target: string;
  amount: number; // UAT amount
  signature?: string;
  previous?: string;
  work?: number;
}

export interface SendResponse {
  status: 'success' | 'error';
  tx_hash?: string;
  initial_power?: number;
  msg?: string;
  error?: string;
}

export interface BurnRequest {
  coin_type: 'btc' | 'eth';
  txid: string;
  recipient_address?: string;
}

export interface BurnResponse {
  status: 'success' | 'error';
  tx_hash?: string;
  minted_uat?: number;
  initial_power?: number;
  msg?: string;
  error?: string;
}

export interface Transaction {
  hash?: string;
  from: string;
  to: string;
  amount: number; // UAT amount
  timestamp?: number;
  type: string;
}

export interface FaucetResponse {
  status: 'success' | 'error';
  amount_uat?: number;
  msg?: string;
  error?: string;
}

export interface ApiError {
  message: string;
  code: string;
  details?: any;
}

// Error handler
export function handleApiError(error: any): ApiError {
  if (axios.isAxiosError(error)) {
    if (error.response) {
      // Server responded with error status
      const statusCode = error.response.status;
      let message = error.response.data?.msg || error.response.data?.error || 'Server error';
      
      switch (statusCode) {
        case 400:
          message = `Bad Request: ${message}`;
          break;
        case 403:
          message = `Forbidden: ${message}`;
          break;
        case 404:
          message = `Not Found: ${message}`;
          break;
        case 429:
          message = `Rate Limited: ${message}`;
          break;
        case 500:
          message = `Server Error: ${message}`;
          break;
        case 503:
          message = 'Service Unavailable: Node is syncing or offline';
          break;
      }
      
      return {
        message,
        code: `HTTP_${statusCode}`,
        details: error.response.data,
      };
    } else if (error.request) {
      // Network error (node offline)
      return {
        message: 'Cannot connect to node. Make sure the backend is running and accessible.',
        code: 'NETWORK_ERROR',
      };
    }
  }
  
  return {
    message: error.message || 'Unknown error occurred',
    code: 'UNKNOWN_ERROR',
  };
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

/**
 * Send transaction
 */
export async function sendTransaction(request: SendRequest): Promise<SendResponse> {
  try {
    const response = await api.post<SendResponse>('/send', request);
    return response.data;
  } catch (error) {
    const apiError = handleApiError(error);
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

    if (!response.ok) {
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
    } = await api.post<BurnResponse>('/burn', request);
    return response.data;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to submit burn:', apiError.message);
    
    // Return error response format
    return {
      status: 'error',
      error: apiError.message,
    };
  }
}

/**
 * Get transaction history
 */
export async function getHistory(address: string): Promise<Transaction[]> {
  try {
    // Try /history/{address} first (if exists)
    const response = await api.get<{ transactions: Transaction[] }>(`/history/${address}`);
    return response.data.transactions || [];
  } catch (error) {
export async function getHistory(address: string): Promise<Transaction[]> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/history/${address}`);
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : (data.transactions || []);
  } catch (error) {
    console.error('Failed to get history:', error
    const response = await api.post<FaucetResponse>('/faucet', { address });
    return response.data;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to claim faucet:', apiError.message);
    
    return {
export async function requestFaucet(address: string): Promise<FaucetResult> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/faucet`, {
      method: 'POST',
      body: JSON.stringify({ address }),
    });

    const data = await response.json();

export async function getValidators(): Promise<Validator[]> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/validators`);
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : (data.validators || []);
  } catch (error) {
    console.error('Failed to get validators:', error
      amount: data.amount,
      txHash: data.tx_hash,
    };
  } catch (error: any) {
    return {
      success: false,
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
}

export interface Transaction {
  hash: string;
  from: string;
  to: string;
  amount: number;
  timestamp: number;
  tx_type: string;
}

export interface FaucetResult {
  success: boolean;
  message: string;
  amount?: number;
  txHash?: string;
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
  transactions?: Transaction[]; const normalizedUrl = url.replace(/\/+$/, '');
    const response = await fetch(`${normalizedUrl}/node-info`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(8000),
    });

    if (response.ok) {
      const data = await response.json();
      return {
        success: true,
        message: `Connected to ${data.chain_name || 'UAT'} (Block #${data.block_height || 0})`,
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
      message: error.name === 'TimeoutError' ? 'Connection timeout' : (error.message || 'Network error'),
    };
  }
}
