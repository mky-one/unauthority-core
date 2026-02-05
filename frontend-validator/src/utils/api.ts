/**
 * Unauthority Validator Dashboard API Client
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
    const response = await fetchWithTimeout(`${getApiUrl()}/node-info`);
    if (!response.ok) return null;
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch node info:', error);
    return null;
  }
}

export async function getBalance(address: string): Promise<Balance | null> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/balance/${address}`);
    if (!response.ok) return null;
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch balance:', error);
    return null;
  }
}

export async function getValidators(): Promise<ValidatorInfo[]> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/validators`);
    if (!response.ok) return [];
    const data = await response.json();
    return Array.isArray(data) ? data : (data.validators || []);
  } catch (error) {
    console.error('Failed to fetch validators:', error);
    return [];
  }
}

export async function getRecentBlocks(): Promise<Block[]> {
  try {
    const response = await fetchWithTimeout(`${getApiUrl()}/block`);
    if (!response.ok) return [];
    const data = await response.json();
    return data ? [data] : [];
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
