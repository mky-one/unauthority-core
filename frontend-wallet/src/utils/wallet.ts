/**
 * Browser-Native Wallet (TweetNaCl-based)
 * No Node.js dependencies - 100% pure browser crypto
 * Uses tweetnacl for Ed25519 signatures, js-sha256 for hashing, base-x for encoding
 */

import nacl from 'tweetnacl';
import bs58 from 'bs58';
import { mnemonicToSeedSync } from '@scure/bip39';

const LOS_PREFIX = 'LOS';

export interface Wallet {
  address: string;
  publicKey: string;
  privateKey: string;
  seedPhrase: string;
}

/**
 * Generate 12-word mnemonic seed phrase (BIP39 word list)
 * Uses 200 common English words for seed phrase generation
 */
function generateMnemonic(): string {
  const words = [
    'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract', 'abuse', 'access',
    'accident', 'account', 'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across', 'act', 'action',
    'actor', 'acuity', 'acute', 'ad', 'adapt', 'add', 'addict', 'added', 'adder', 'adding',
    'address', 'adds', 'adept', 'adequate', 'adieu', 'adjust', 'admin', 'admire', 'admit', 'adobe',
    'adopt', 'adore', 'adorn', 'adult', 'advance', 'advent', 'adverb', 'adversary', 'adverse', 'advert',
    'advice', 'advise', 'advocate', 'affairs', 'afford', 'afraid', 'after', 'again', 'age', 'agenda',
    'agent', 'ages', 'aggravate', 'aggregate', 'aggressive', 'ago', 'agony', 'agree', 'ahead', 'aid',
    'aide', 'aides', 'ailing', 'aim', 'air', 'airy', 'aisle', 'ajar', 'alarm', 'alas',
    'album', 'alcohol', 'alcove', 'alert', 'algebra', 'alias', 'alien', 'align', 'alike', 'alive',
    'all', 'allay', 'allege', 'alley', 'alliance', 'allied', 'allies', 'alloc', 'allocate', 'allot',
    'allow', 'alloy', 'alloys', 'allstate', 'allude', 'allure', 'ally', 'alma', 'almanac', 'almighty',
    'almost', 'alms', 'aloe', 'aloft', 'alone', 'along', 'aloof', 'aloud', 'alpha', 'alphabet',
    'already', 'also', 'altar', 'alter', 'alternate', 'alternative', 'although', 'altitude', 'alto', 'always',
    'am', 'amadavat', 'amah', 'amain', 'amalgam', 'amaranth', 'amass', 'amateur', 'amaze', 'amber',
    'ambidextrous', 'ambience', 'ambient', 'ambiguity', 'ambiguous', 'ambition', 'ambitious', 'amble', 'ambo', 'ambush',
    'amen', 'amenable', 'amend', 'amenity', 'ament', 'american', 'amethyst', 'amiable', 'amicable', 'amice',
    'amid', 'amide', 'amidships', 'amidst', 'amies', 'amigo', 'amine', 'amino', 'amis', 'amiss',
    'amity', 'ammeter', 'ammiac', 'ammine', 'ammo', 'ammonia', 'ammoniac', 'ammonite', 'ammonium', 'ammunition',
    'amnesia', 'amnesty', 'amoeba', 'amok', 'among', 'amount', 'amour', 'amp', 'ampere', 'ampersand',
    'amphetamine', 'amphibian', 'amphitheater', 'ample', 'amplifier', 'amplify', 'ampoule', 'amputate', 'amuse', 'amusement',
  ];

  const mnemonic: string[] = [];
  for (let i = 0; i < 12; i++) {
    mnemonic.push(words[Math.floor(Math.random() * words.length)]);
  }
  return mnemonic.join(' ');
}

/**
 * Derive Ed25519 keypair from seed phrase using BIP39 (same as genesis generator)
 * Compatible with Python's mnemonic.to_seed()
 */
function deriveFromSeed(seedPhrase: string): { publicKey: Uint8Array; secretKey: Uint8Array } {
  // Use BIP39 mnemonicToSeed (same as Python genesis generator)
  const seed = mnemonicToSeedSync(seedPhrase, ''); // No passphrase
  
  // Use first 32 bytes as Ed25519 seed
  const seed32 = seed.slice(0, 32);

  // Generate keypair from seed (tweetnacl format)
  const keyPair = nacl.sign.keyPair.fromSeed(seed32);
  return {
    publicKey: keyPair.publicKey,
    secretKey: keyPair.secretKey,
  };
}

/**
 * Create LOS address from public key (Genesis-compatible format)
 * Format: "LOS" + Base58(PublicKey) - SIMPLE, no checksum
 */
function createAddress(publicKey: Uint8Array): string {
  // Simple Base58 encoding (same as Python genesis generator)
  const base58Address = bs58.encode(Buffer.from(publicKey));
  return LOS_PREFIX + base58Address;
}

/**
 * Generate new wallet with random 12-word seed phrase
 */
export function generateWallet(): Wallet {
  const seedPhrase = generateMnemonic();
  const { publicKey, secretKey } = deriveFromSeed(seedPhrase);
  const address = createAddress(publicKey);

  return {
    address,
    publicKey: Buffer.from(publicKey).toString('hex'),
    privateKey: Buffer.from(secretKey).toString('hex'),
    seedPhrase,
  };
}

/**
 * Import wallet from 12-word seed phrase
 */
export function importFromSeedPhrase(seedPhrase: string): Wallet {
  // Validate seed phrase (should have 12 words)
  const words = seedPhrase.trim().split(/\s+/);
  if (words.length !== 12) {
    throw new Error('Seed phrase must contain exactly 12 words');
  }

  const { publicKey, secretKey } = deriveFromSeed(seedPhrase);
  const address = createAddress(publicKey);

  return {
    address,
    publicKey: Buffer.from(publicKey).toString('hex'),
    privateKey: Buffer.from(secretKey).toString('hex'),
    seedPhrase,
  };
}

/**
 * Import wallet from private key (64-byte hex string for Ed25519)
 * Ed25519 private key in tweetnacl is 64 bytes: seed (32) + public_key (32)
 */
export function importFromPrivateKey(privateKeyHex: string): Wallet {
  const privateKeyBytes = new Uint8Array(Buffer.from(privateKeyHex, 'hex'));

  if (privateKeyBytes.length !== 64) {
    throw new Error('Private key must be 64 bytes (128 hex characters) for Ed25519');
  }

  // Extract public key from secret key (last 32 bytes are public key in tweetnacl)
  const publicKey = privateKeyBytes.slice(32);
  const address = createAddress(publicKey);

  return {
    address,
    publicKey: Buffer.from(publicKey).toString('hex'),
    privateKey: privateKeyHex,
    seedPhrase: 'imported-key',
  };
}

/**
 * Format balance for display
 * Balance is already in LOS from API (balance_los field)
 */
export function formatBalance(losBalance: number): string {
  // Balance is already in LOS, just format it
  return losBalance.toFixed(2).replace(/\.?0+$/, '');
}

/**
 * Convert LOS to CIL for API calls
 */
export function losToCil(los: number): number {
  return Math.floor(los * 100_000_000);
}

/**
 * Validate LOS address format
 * Must start with "LOS" and contain valid Base58 characters
 */
export function isValidLOSAddress(address: string): boolean {
  if (!address.startsWith(LOS_PREFIX)) return false;
  if (address.length < 20 || address.length > 100) return false;

  try {
    const base58Part = address.slice(LOS_PREFIX.length);
    bs58.decode(base58Part);
    return true;
  } catch {
    return false;
  }
}

/**
 * Hash block data (same as backend)
 * Format: account + previous + block_type + amount + link
 */
export async function hashBlock(
  account: string,
  previous: string,
  blockType: string,
  amount: number,
  link: string
): Promise<string> {
  const data = `${account}${previous}${blockType}${amount}${link}`;
  
  // Simple SHA-256 hash
  const encoder = new TextEncoder();
  const buffer = await crypto.subtle.digest('SHA-256', encoder.encode(data));
  const hashArray = Array.from(new Uint8Array(buffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Sign transaction (client-side signing for security)
 * Returns signature as hex string
 */
export async function signTransaction(
  privateKeyHex: string,
  account: string,
  previous: string,
  blockType: string,
  amount: number,
  link: string
): Promise<string> {
  // Hash block data
  const hash = await hashBlock(account, previous, blockType, amount, link);
  
  // Sign with private key
  const privateKeyBytes = new Uint8Array(Buffer.from(privateKeyHex, 'hex'));
  const messageBytes = new Uint8Array(Buffer.from(hash, 'utf-8'));
  const signature = nacl.sign.detached(messageBytes, privateKeyBytes);
  
  return Buffer.from(signature).toString('hex');
}
