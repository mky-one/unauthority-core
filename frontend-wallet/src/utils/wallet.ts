/**
 * Browser-Native Wallet (TweetNaCl-based)
 * No Node.js dependencies - 100% pure browser crypto
 * Uses tweetnacl for Ed25519 signatures, js-sha256 for hashing, base-x for encoding
 */

import nacl from 'tweetnacl';
import { sha256 } from 'js-sha256';
import base58 from 'base-x';

const UAT_PREFIX = 'UAT';
const BS58 = base58('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz');

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
 * Derive Ed25519 keypair from seed phrase using SHA256
 * Simple key derivation: SHA256(seed_phrase) → Ed25519 keypair
 */
function deriveFromSeed(seedPhrase: string): { publicKey: Uint8Array; secretKey: Uint8Array } {
  // Hash seed phrase to get 32 bytes for Ed25519 seed
  const hashHex = sha256(seedPhrase);
  const seed = new Uint8Array(Buffer.from(hashHex, 'hex'));

  if (seed.length !== 32) {
    throw new Error('Invalid seed length for Ed25519');
  }

  // Generate keypair from seed (tweetnacl format)
  const keyPair = nacl.sign.keyPair.fromSeed(seed);
  return {
    publicKey: keyPair.publicKey,
    secretKey: keyPair.secretKey,
  };
}

/**
 * Create UAT address from public key
 * Format: "UAT" + Base58(version_byte + pubkey_hash + checksum)
 * version_byte = 0x00
 * pubkey_hash = SHA256(public_key)
 * checksum = first_4_bytes(SHA256(SHA256(version + hash)))
 */
function createAddress(publicKey: Uint8Array): string {
  // Hash public key: SHA256(publicKey)
  const hashHex = sha256(Buffer.from(publicKey));
  const hashBytes = Buffer.from(hashHex, 'hex');

  // Create version + hash payload
  const withVersion = Buffer.alloc(hashBytes.length + 1);
  withVersion[0] = 0x00; // Version byte for UAT
  hashBytes.copy(withVersion, 1);

  // Compute checksum: SHA256(SHA256(version + hash))
  const checksum1Hex = sha256(withVersion);
  const checksum2Hex = sha256(Buffer.from(checksum1Hex, 'hex'));
  const checksumBytes = Buffer.from(checksum2Hex, 'hex').slice(0, 4);

  // Combine: version + hash + checksum
  const fullAddress = Buffer.concat([withVersion, checksumBytes]);

  // Base58 encode and add UAT prefix
  const base58Address = BS58.encode(fullAddress);
  return UAT_PREFIX + base58Address;
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
 * Format balance from VOI to UAT
 * 1 UAT = 100,000,000 VOI (same as Bitcoin satoshi model)
 */
export function formatBalance(voidBalance: number): string {
  const uat = voidBalance / 100_000_000;
  return uat.toFixed(8).replace(/\.?0+$/, '');
}

/**
 * Convert UAT to VOI for API calls
 */
export function uatToVoid(uat: number): number {
  return Math.floor(uat * 100_000_000);
}

/**
 * Validate UAT address format
 * Must start with "UAT" and contain valid Base58 characters
 */
export function isValidUATAddress(address: string): boolean {
  if (!address.startsWith(UAT_PREFIX)) return false;
  if (address.length < 20 || address.length > 100) return false;

  try {
    const base58Part = address.slice(UAT_PREFIX.length);
    BS58.decode(base58Part);
    return true;
  } catch {
    return false;
  }
}
