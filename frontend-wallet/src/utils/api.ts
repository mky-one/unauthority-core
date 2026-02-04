/**
 * Unauthority REST API Client
 * Connects to local node at http://localhost:3030
 */

import axios from 'axios';

const API_BASE = 'http://localhost:3030';
const API_TIMEOUT = 3000; // 3 seconds

// Create axios instance with timeout
const api = axios.create({
  baseURL: API_BASE,
  timeout: API_TIMEOUT,
});

export interface Balance {
  balance: number;
  address: string;
}

export interface NodeInfo {
  chain_id: string;
  total_supply: number;
  remaining_supply: number;
  total_burned_usd: number;
  eth_price_usd?: number;
  btc_price_usd?: number;
}

export interface BurnRequest {
  coin_type: 'btc' | 'eth';
  txid: string;
  recipient_address?: string; // Optional: address to receive minted UAT
}

export interface BurnResponse {
  status: 'success' | 'error';
  message?: string;
  msg?: string;
  initial_power?: number;
  error?: string;
}

export interface SendRequest {
  from: string;
  to: string;
  amount: number;
}

export interface Transaction {
  hash: string;
  from: string;
  to: string;
  amount: number;
  timestamp: number;
  type: string;
}

/**
 * Get account balance
 */
export async function getBalance(address: string): Promise<number> {
  try {
    const response = await api.get(`/balance/${address}`);
    return response.data.balance || 0;
  } catch (error) {
    console.error('Failed to fetch balance:', error);
    return 0;
  }
}

/**
 * Get node info (supply, burned amount, oracle prices)
 */
export async function getNodeInfo(): Promise<NodeInfo | null> {
  try {
    const response = await api.get('/node-info');
    return response.data;
  } catch (error) {
    console.error('Failed to fetch node info:', error);
    return null;
  }
}

/**
 * Submit burn transaction (BTC or ETH)
 */
export async function submitBurn(request: BurnRequest): Promise<BurnResponse> {
  try {
    const response = await axios.post(`${API_BASE}/burn`, request);
    return response.data;
  } catch (error: any) {
    return {
      status: 'error',
      error: error.response?.data?.error || error.message || 'Network error',
    };
  }
}

/**
 * Send UAT to another address
 */
export async function sendTransaction(request: SendRequest): Promise<any> {
  try {
    const response = await axios.post(`${API_BASE}/send`, request);
    return response.data;
  } catch (error: any) {
    throw new Error(error.response?.data?.error || error.message || 'Failed to send transaction');
  }
}

/**
 * Get transaction history for address
 */
export async function getHistory(address: string): Promise<Transaction[]> {
  try {
    const response = await api.get(`/account/${address}`);
    return response.data.transactions || [];
  } catch (error) {
    console.error('Failed to fetch history:', error);
    return [];
  }
}

/**
 * Check if node is reachable
 */
export async function checkNodeConnection(): Promise<boolean> {
  try {
    console.log('[API] Checking node connection at:', API_BASE);
    const response = await axios.get(`${API_BASE}/node-info`, { timeout: 5000 });
    console.log('[API] Node connection successful:', response.status);
    return response.status === 200;
  } catch (error: any) {
    console.error('[API] Node connection failed:', error.message, error.code);
    return false;
  }
}
