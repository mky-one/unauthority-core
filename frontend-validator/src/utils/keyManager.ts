import CryptoJS from 'crypto-js';

const STORAGE_KEY = 'uat_validator_keys';
const SESSION_TIMEOUT = 15 * 60 * 1000; // 15 minutes

interface EncryptedKeys {
  encryptedPrivateKey: string;
  publicKey: string;
  address: string;
  timestamp: number;
}

let sessionPassword: string | null = null;
let sessionTimeout: NodeJS.Timeout | null = null;

/**
 * Encrypt private key with user password (AES-256-GCM)
 */
export function encryptPrivateKey(privateKey: string, password: string): string {
  return CryptoJS.AES.encrypt(privateKey, password).toString();
}

/**
 * Decrypt private key with user password
 */
export function decryptPrivateKey(encryptedKey: string, password: string): string | null {
  try {
    const bytes = CryptoJS.AES.decrypt(encryptedKey, password);
    const decrypted = bytes.toString(CryptoJS.enc.Utf8);
    return decrypted || null;
  } catch (error) {
    console.error('Decryption failed:', error);
    return null;
  }
}

/**
 * Store encrypted keys in localStorage
 */
export function storeKeys(privateKey: string, publicKey: string, address: string, password: string): void {
  const encrypted = encryptPrivateKey(privateKey, password);
  
  const data: EncryptedKeys = {
    encryptedPrivateKey: encrypted,
    publicKey,
    address,
    timestamp: Date.now(),
  };
  
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  
  // Store password in memory for session
  sessionPassword = password;
  resetSessionTimeout();
}

/**
 * Get stored keys (requires password to decrypt)
 */
export function getStoredKeys(password: string): { privateKey: string; publicKey: string; address: string } | null {
  const stored = localStorage.getItem(STORAGE_KEY);
  if (!stored) return null;
  
  try {
    const data: EncryptedKeys = JSON.parse(stored);
    const privateKey = decryptPrivateKey(data.encryptedPrivateKey, password);
    
    if (!privateKey) return null;
    
    // Store password for session
    sessionPassword = password;
    resetSessionTimeout();
    
    return {
      privateKey,
      publicKey: data.publicKey,
      address: data.address,
    };
  } catch (error) {
    console.error('Failed to parse stored keys:', error);
    return null;
  }
}

/**
 * Check if validator keys are configured
 */
export function isConfigured(): boolean {
  return localStorage.getItem(STORAGE_KEY) !== null;
}

/**
 * Get public address without password
 */
export function getPublicAddress(): string | null {
  const stored = localStorage.getItem(STORAGE_KEY);
  if (!stored) return null;
  
  try {
    const data: EncryptedKeys = JSON.parse(stored);
    return data.address;
  } catch {
    return null;
  }
}

/**
 * Clear session (logout)
 */
export function clearSession(): void {
  sessionPassword = null;
  if (sessionTimeout) {
    clearTimeout(sessionTimeout);
    sessionTimeout = null;
  }
}

/**
 * Delete all stored keys (cannot be recovered!)
 */
export function deleteKeys(): void {
  localStorage.removeItem(STORAGE_KEY);
  clearSession();
}

/**
 * Reset session timeout (auto-logout after inactivity)
 */
function resetSessionTimeout(): void {
  if (sessionTimeout) {
    clearTimeout(sessionTimeout);
  }
  
  sessionTimeout = setTimeout(() => {
    clearSession();
    alert('Session expired due to inactivity. Please unlock again.');
    window.location.reload();
  }, SESSION_TIMEOUT);
}

/**
 * Check if session is active
 */
export function isSessionActive(): boolean {
  return sessionPassword !== null;
}

/**
 * Get session password (for auto-decrypt)
 */
export function getSessionPassword(): string | null {
  return sessionPassword;
}

/**
 * Generate random password for backup encryption
 */
export function generateBackupPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*';
  let password = '';
  for (let i = 0; i < 16; i++) {
    password += chars[Math.floor(Math.random() * chars.length)];
  }
  return password;
}

/**
 * Download encrypted backup file
 */
export function downloadBackup(seedPhrase: string, privateKey: string, publicKey: string, address: string): void {
  const backup = {
    version: '1.0',
    created_at: new Date().toISOString(),
    seed_phrase: seedPhrase,
    private_key: privateKey,
    public_key: publicKey,
    address: address,
    warning: '⚠️ KEEP THIS FILE SECURE! Anyone with this file can control your validator.',
  };
  
  const json = JSON.stringify(backup, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = `unauthority-validator-backup-${address.slice(4, 12)}-${Date.now()}.json`;
  a.click();
  
  URL.revokeObjectURL(url);
}
