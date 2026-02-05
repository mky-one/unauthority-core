/**
 * Unauthority REST API Client (IMPROVED with Error Handling & Retry Logic)
 * Connects to node with automatic reconnection and user-friendly errors
 * 
 * SUPPORTS DYNAMIC ENDPOINT CHANGES FOR REMOTE TESTNET
 */

import axios, { AxiosError, AxiosInstance } from 'axios';

const API_TIMEOUT = 10000; // 10 seconds for remote connections
const MAX_RETRIES = 2;

// Get API base from localStorage (dynamic, changes when user updates settings)
export const getApiBase = (): string => {
  if (typeof window !== 'undefined') {
    return localStorage.getItem('api_base') || 'http://localhost:3030';
  }
  return 'http://localhost:3030';
};

export const setApiBase = (url: string) => {
  if (typeof window !== 'undefined') {
    // Normalize URL - remove trailing slashes
    const normalizedUrl = url.replace(/\/+$/, '');
    localStorage.setItem('api_base', normalizedUrl);
    console.log('[API] Endpoint updated to:', normalizedUrl);
  }
};

// Export alias for consistency
export const getApiBaseUrl = getApiBase;

// Create axios instance dynamically (gets current endpoint each time)
const createApiClient = (): AxiosInstance => {
  const client = axios.create({
    timeout: API_TIMEOUT,
    headers: {
      'Content-Type': 'application/json',
    },
  });

  // Request interceptor - set baseURL dynamically
  client.interceptors.request.use((config) => {
    config.baseURL = getApiBase();
    return config;
  });

  // Response interceptor for retry logic
  client.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
      const config = error.config as any;
      
      // Initialize retry count
      if (!config || config.__retryCount === undefined) {
        config.__retryCount = 0;
      }
      
      // Retry on network errors or 5xx errors
      const shouldRetry = 
        (!error.response && error.code !== 'ECONNABORTED') || // Network error
        (error.response && error.response.status >= 500); // Server error
      
      if (config.__retryCount < MAX_RETRIES && shouldRetry) {
        config.__retryCount += 1;
        
        // Exponential backoff
        const delay = Math.min(1000 * Math.pow(2, config.__retryCount - 1), 3000);
        console.log(`[API] Retrying request (${config.__retryCount}/${MAX_RETRIES}) after ${delay}ms...`);
        
        await new Promise(resolve => setTimeout(resolve, delay));
        return client.request(config);
      }
      
      return Promise.reject(error);
    }
  );

  return client;
};

const api = createApiClient();

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

/**
 * Get account balance
 */
export async function getBalance(address: string): Promise<number> {
  try {
    const response = await api.get<Balance>(`/balance/${address}`);
    // Return UAT amount
    return response.data.balance_uat || 0;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to fetch balance:', apiError.message);
    
    // Return 0 for 404 (address not found = zero balance)
    if (apiError.code === 'HTTP_404') {
      return 0;
    }
    
    throw apiError;
  }
}

/**
 * Get node info
 */
export async function getNodeInfo(): Promise<NodeInfo> {
  try {
    const response = await api.get<NodeInfo>('/node-info');
    return response.data;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to fetch node info:', apiError.message);
    throw apiError;
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
    console.error('[API] Failed to send transaction:', apiError.message);
    throw apiError;
  }
}

/**
 * Submit burn transaction
 */
export async function submitBurn(request: BurnRequest): Promise<BurnResponse> {
  try {
    const response = await api.post<BurnResponse>('/burn', request);
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
    const apiError = handleApiError(error);
    console.error('[API] Failed to fetch history:', apiError.message);
    return [];
  }
}

/**
 * Claim testnet tokens from faucet
 */
export async function claimFaucet(address: string): Promise<FaucetResponse> {
  try {
    const response = await api.post<FaucetResponse>('/faucet', { address });
    return response.data;
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to claim faucet:', apiError.message);
    
    return {
      status: 'error',
      error: apiError.message,
    };
  }
}

/**
 * Check node health
 */
export async function checkNodeConnection(): Promise<boolean> {
  try {
    const baseUrl = getApiBase();
    console.log('[API] Checking node connection at:', baseUrl);
    const response = await api.get('/node-info', { timeout: 5000 });
    console.log('[API] Node connection successful:', response.status);
    return response.status === 200;
  } catch (error: any) {
    console.error('[API] Node connection failed:', error.message);
    return false;
  }
}

/**
 * Get validators list
 */
export async function getValidators(): Promise<any[]> {
  try {
    const response = await api.get('/validators');
    return response.data.validators || [];
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to fetch validators:', apiError.message);
    return [];
  }
}

/**
 * Get recent blocks
 */
export async function getRecentBlocks(): Promise<any[]> {
  try {
    const response = await api.get('/blocks/recent');
    return response.data.blocks || [];
  } catch (error) {
    const apiError = handleApiError(error);
    console.error('[API] Failed to fetch blocks:', apiError.message);
    return [];
  }
}

/**
 * Export current API base URL
 */
export function getCurrentApiUrl(): string {
  return getApiBase();
}

/**
 * Test connection to a specific endpoint (without changing current)
 */
export async function testEndpoint(url: string): Promise<{ success: boolean; message: string; data?: any }> {
  try {
    const normalizedUrl = url.replace(/\/+$/, '');
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
