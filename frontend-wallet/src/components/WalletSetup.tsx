import { useState } from 'react';
import { Wallet, Download, Key, AlertCircle, Copy } from 'lucide-react';
import { generateWallet, importFromSeedPhrase, importFromPrivateKey } from '../utils/wallet';
import { useWalletStore } from '../store/walletStore';

type Mode = 'welcome' | 'create' | 'import-seed' | 'import-key' | 'backup';

export default function WalletSetup() {
  const [mode, setMode] = useState<Mode>('welcome');
  const [seedPhrase, setSeedPhrase] = useState('');
  const [privateKey, setPrivateKey] = useState('');
  const [error, setError] = useState('');
  const [generatedWallet, setGeneratedWallet] = useState<any>(null);
  const [seedConfirmed, setSeedConfirmed] = useState(false);
  const { setWallet } = useWalletStore();

  const handleCreateWallet = () => {
    const wallet = generateWallet();
    setGeneratedWallet(wallet);
    setMode('backup');
  };

  const handleImportSeed = () => {
    try {
      setError('');
      const wallet = importFromSeedPhrase(seedPhrase.trim());
      setWallet(wallet);
    } catch (err: any) {
      setError(err.message || 'Invalid seed phrase');
    }
  };

  const handleImportKey = () => {
    try {
      setError('');
      const wallet = importFromPrivateKey(privateKey.trim());
      setWallet(wallet);
    } catch (err: any) {
      setError(err.message || 'Invalid private key');
    }
  };

  const handleConfirmBackup = () => {
    if (generatedWallet && seedConfirmed) {
      setWallet(generatedWallet);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  if (mode === 'welcome') {
    return (
      <div className="h-screen flex items-center justify-center bg-gradient-to-br from-uat-dark via-uat-gray to-uat-dark">
        <div className="max-w-md w-full mx-4">
          <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8 shadow-2xl">
            {/* UAT Logo */}
            <div className="flex justify-center mb-6">
              <div className="relative w-32 h-32">
                {/* Try JPEG first, fallback to SVG, then fallback to icon */}
                <img 
                  src="/assets/uat-logo.jpeg" 
                  alt="UAT Logo" 
                  className="w-32 h-32 rounded-full object-cover shadow-2xl"
                  onError={(e) => {
                    // Try SVG next
                    (e.target as HTMLImageElement).src = '/assets/uat-logo.svg';
                    (e.target as HTMLImageElement).onerror = () => {
                      // SVG failed too, show CSS fallback
                      (e.target as HTMLImageElement).style.display = 'none';
                      const fallback = document.createElement('div');
                      fallback.className = 'w-32 h-32 bg-gradient-to-br from-uat-blue to-uat-cyan rounded-full flex items-center justify-center shadow-2xl';
                      fallback.innerHTML = '<svg class="w-16 h-16 text-white" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm3.5-9c.83 0 1.5-.67 1.5-1.5S16.33 8 15.5 8 14 8.67 14 9.5s.67 1.5 1.5 1.5zm-7 0c.83 0 1.5-.67 1.5-1.5S9.33 8 8.5 8 7 8.67 7 9.5 7.67 11 8.5 11zm3.5 6.5c2.33 0 4.31-1.46 5.11-3.5H6.89c.8 2.04 2.78 3.5 5.11 3.5z"/></svg>';
                      (e.target as HTMLImageElement).parentElement?.appendChild(fallback);
                    };
                  }}
                />
              </div>
            </div>
            
            <h1 className="text-3xl font-bold text-center mb-2">Unauthority Wallet</h1>
            <p className="text-gray-400 text-center mb-8">
              Burn BTC/ETH to mint UAT. 100% local, 100% private.
            </p>

            <div className="space-y-3">
              <button
                onClick={() => setMode('create')}
                className="w-full bg-gradient-to-r from-uat-blue to-uat-cyan text-white py-4 rounded-xl font-semibold hover:shadow-lg transition-all flex items-center justify-center space-x-2"
              >
                <Wallet className="w-5 h-5" />
                <span>Create New Wallet</span>
              </button>

              <button
                onClick={() => setMode('import-seed')}
                className="w-full bg-uat-dark border border-gray-600 text-white py-4 rounded-xl font-semibold hover:bg-gray-800 transition-all flex items-center justify-center space-x-2"
              >
                <Download className="w-5 h-5" />
                <span>Import from Seed Phrase</span>
              </button>

              <button
                onClick={() => setMode('import-key')}
                className="w-full bg-uat-dark border border-gray-600 text-white py-4 rounded-xl font-semibold hover:bg-gray-800 transition-all flex items-center justify-center space-x-2"
              >
                <Key className="w-5 h-5" />
                <span>Import from Private Key</span>
              </button>
            </div>

            <div className="mt-6 p-4 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
              <div className="flex items-start space-x-2">
                <AlertCircle className="w-5 h-5 text-yellow-500 flex-shrink-0 mt-0.5" />
                <p className="text-sm text-yellow-200">
                  Your private keys never leave your device. Always backup your seed phrase safely.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'create') {
    return (
      <div className="h-screen flex items-center justify-center bg-gradient-to-br from-uat-dark via-uat-gray to-uat-dark">
        <div className="max-w-md w-full mx-4">
          <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8 shadow-2xl">
            <h2 className="text-2xl font-bold mb-6">Create New Wallet</h2>
            
            <div className="mb-6 p-4 bg-blue-500/10 border border-blue-500/30 rounded-lg">
              <div className="flex items-start space-x-2">
                <AlertCircle className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <div className="text-sm text-blue-200">
                  <p className="font-semibold mb-1">Before you proceed:</p>
                  <ul className="list-disc list-inside space-y-1 text-xs">
                    <li>You will receive a 12-word seed phrase</li>
                    <li>Write it down on paper (NOT digitally)</li>
                    <li>Store it in a safe place</li>
                    <li>Anyone with this phrase can access your wallet</li>
                  </ul>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <button
                onClick={handleCreateWallet}
                className="w-full bg-gradient-to-r from-uat-blue to-uat-cyan text-white py-3 rounded-xl font-semibold hover:shadow-lg transition-all"
              >
                Generate Wallet
              </button>

              <button
                onClick={() => setMode('welcome')}
                className="w-full bg-uat-dark border border-gray-600 text-white py-3 rounded-xl font-semibold hover:bg-gray-800 transition-all"
              >
                Back
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'backup' && generatedWallet) {
    const words = generatedWallet.seedPhrase?.split(' ') || [];
    
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-uat-dark via-uat-gray to-uat-dark overflow-y-auto py-8">
        <div className="max-w-2xl w-full mx-4 my-auto">
          <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8 shadow-2xl">
            <h2 className="text-2xl font-bold mb-2">Backup Your Seed Phrase</h2>
            <p className="text-gray-400 mb-6">Write down these 12 words in order. You'll need them to recover your wallet.</p>

            <div className="grid grid-cols-3 gap-3 mb-6">
              {words.map((word: string, index: number) => (
                <div key={index} className="bg-uat-dark border border-gray-600 rounded-lg p-3">
                  <span className="text-xs text-gray-500">#{index + 1}</span>
                  <p className="font-mono font-semibold">{word}</p>
                </div>
              ))}
            </div>

            <button
              onClick={() => copyToClipboard(generatedWallet.seedPhrase || '')}
              className="w-full mb-4 bg-uat-dark border border-gray-600 text-white py-2 rounded-lg hover:bg-gray-800 transition-all flex items-center justify-center space-x-2"
            >
              <Copy className="w-4 h-4" />
              <span>Copy to Clipboard</span>
            </button>

            <div className="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
              <div className="flex items-start space-x-2">
                <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                <div className="text-sm text-red-200">
                  <p className="font-semibold mb-1">⚠️ CRITICAL WARNING:</p>
                  <ul className="list-disc list-inside space-y-1 text-xs">
                    <li>Never share this phrase with anyone</li>
                    <li>Unauthority team will NEVER ask for it</li>
                    <li>Loss of this phrase = permanent loss of funds</li>
                    <li>Store offline (paper backup recommended)</li>
                  </ul>
                </div>
              </div>
            </div>

            <label className="flex items-center space-x-3 mb-6 cursor-pointer">
              <input
                type="checkbox"
                checked={seedConfirmed}
                onChange={(e) => setSeedConfirmed(e.target.checked)}
                className="w-5 h-5 rounded border-gray-600 text-uat-blue focus:ring-uat-blue"
              />
              <span className="text-sm">I have safely backed up my seed phrase</span>
            </label>

            <button
              onClick={handleConfirmBackup}
              disabled={!seedConfirmed}
              className={`w-full py-3 rounded-xl font-semibold transition-all ${
                seedConfirmed
                  ? 'bg-gradient-to-r from-uat-blue to-uat-cyan text-white hover:shadow-lg'
                  : 'bg-gray-700 text-gray-500 cursor-not-allowed'
              }`}
            >
              Continue to Wallet
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'import-seed') {
    return (
      <div className="h-screen flex items-center justify-center bg-gradient-to-br from-uat-dark via-uat-gray to-uat-dark">
        <div className="max-w-md w-full mx-4">
          <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8 shadow-2xl">
            <h2 className="text-2xl font-bold mb-6">Import from Seed Phrase</h2>
            
            <div className="mb-4">
              <label className="block text-sm font-medium mb-2">12-word Seed Phrase</label>
              <textarea
                value={seedPhrase}
                onChange={(e) => setSeedPhrase(e.target.value)}
                placeholder="word1 word2 word3 ..."
                rows={4}
                className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-3 text-sm font-mono focus:ring-2 focus:ring-uat-blue focus:border-transparent"
              />
            </div>

            {error && (
              <div className="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-sm text-red-200">
                {error}
              </div>
            )}

            <div className="space-y-3">
              <button
                onClick={handleImportSeed}
                className="w-full bg-gradient-to-r from-uat-blue to-uat-cyan text-white py-3 rounded-xl font-semibold hover:shadow-lg transition-all"
              >
                Import Wallet
              </button>

              <button
                onClick={() => setMode('welcome')}
                className="w-full bg-uat-dark border border-gray-600 text-white py-3 rounded-xl font-semibold hover:bg-gray-800 transition-all"
              >
                Back
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (mode === 'import-key') {
    return (
      <div className="h-screen flex items-center justify-center bg-gradient-to-br from-uat-dark via-uat-gray to-uat-dark">
        <div className="max-w-md w-full mx-4">
          <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8 shadow-2xl">
            <h2 className="text-2xl font-bold mb-6">Import from Private Key</h2>
            
            <div className="mb-4">
              <label className="block text-sm font-medium mb-2">Private Key (Hex)</label>
              <input
                type="password"
                value={privateKey}
                onChange={(e) => setPrivateKey(e.target.value)}
                placeholder="0x..."
                className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-3 text-sm font-mono focus:ring-2 focus:ring-uat-blue focus:border-transparent"
              />
            </div>

            {error && (
              <div className="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-sm text-red-200">
                {error}
              </div>
            )}

            <div className="space-y-3">
              <button
                onClick={handleImportKey}
                className="w-full bg-gradient-to-r from-uat-blue to-uat-cyan text-white py-3 rounded-xl font-semibold hover:shadow-lg transition-all"
              >
                Import Wallet
              </button>

              <button
                onClick={() => setMode('welcome')}
                className="w-full bg-uat-dark border border-gray-600 text-white py-3 rounded-xl font-semibold hover:bg-gray-800 transition-all"
              >
                Back
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return null;
}
