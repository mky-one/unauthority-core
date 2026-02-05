const nacl = require('tweetnacl');
const { mnemonicToSeedSync } = require('@scure/bip39');
const bs58 = require('bs58');

const seedPhrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

// BIP39 derivation (same as Python genesis)
const seed = mnemonicToSeedSync(seedPhrase, '');
const seed32 = seed.slice(0, 32);

// Generate keypair
const keyPair = nacl.sign.keyPair.fromSeed(seed32);

// Create address
const address = 'UAT' + bs58.default.encode(Buffer.from(keyPair.publicKey));
const publicKeyHex = Buffer.from(keyPair.publicKey).toString('hex');
const privateKeyHex = Buffer.from(seed32).toString('hex');

console.log('Seed Phrase:', seedPhrase);
console.log('Address:', address);
console.log('Public Key:', publicKeyHex);
console.log('Private Key:', privateKeyHex);
console.log('');
console.log('Expected Address: UATEHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o');
console.log('Match:', address === 'UATEHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o');
