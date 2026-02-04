import axios from 'axios';

const API_BASE = 'http://localhost:3030';
const API_TIMEOUT = 3000; // 3 seconds

// Create axios instance with timeout
const api = axios.create({
  baseURL: API_BASE,
  timeout: API_TIMEOUT,
});

export interface NodeInfo {
  chain_id: string;
  version: string;
  total_supply: number;
  circulating_supply: number;
  validator_count: number;
  peer_count: number;
  block_height: number;
  network_tps: number;
}

export interface Balance {
  address: string;
  balance_void: number;
  balance_uat: number;
}

export interface ValidatorInfo {
  address: string;
  stake: number;
  is_active: boolean;
  uptime_percentage: number;
}

export interface Block {
  hash: string;
  height: number;
  timestamp: number;
  transactions_count: number;
}

export async function getNodeInfo(): Promise<NodeInfo | null> {
  try {
    const response = await api.get('/node-info');
    return response.data;
  } catch (error) {
    console.error('Failed to fetch node info:', error);
    return null;
  }
}

export async function getBalance(address: string): Promise<Balance | null> {
  try {
    const response = await api.get(`/balance/${address}`);
    return response.data;
  } catch (error) {
    console.error('Failed to fetch balance:', error);
    return null;
  }
}

export async function getValidators(): Promise<ValidatorInfo[]> {
  try {
    const response = await api.get('/validators');
    return response.data.validators || [];
  } catch (error) {
    console.error('Failed to fetch validators:', error);
    return [];
  }
}

export async function getRecentBlocks(): Promise<Block[]> {
  try {
    const response = await api.get('/blocks/recent');
    return response.data.blocks || [];
  } catch (error) {
    console.error('Failed to fetch blocks:', error);
    return [];
  }
}

export async function checkNodeConnection(): Promise<boolean> {
  try {
    const info = await getNodeInfo();
    return info !== null;
  } catch {
    return false;
  }
}

export interface SendRequest {
  from: string;
  to: string;
  amount: number;
}

export interface SendResponse {
  success: boolean;
  hash?: string;
  error?: string;
}

export async function sendTransaction(request: SendRequest): Promise<SendResponse> {
  try {
    const response = await api.post('/send', request);
    return response.data;
  } catch (error: any) {
    console.error('Failed to send transaction:', error);
    return {
      success: false,
      error: error.response?.data?.error || error.message || 'Unknown error',
    };
  }
}

export interface WhoamiResponse {
  address: string;
  short: string;
  format: string;
}

export async function getWhoami(): Promise<WhoamiResponse | null> {
  try {
    const response = await api.get('/whoami');
    return response.data;
  } catch (error) {
    console.error('Failed to fetch whoami:', error);
    return null;
  }
}
