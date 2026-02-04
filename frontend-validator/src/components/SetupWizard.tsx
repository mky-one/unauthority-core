import { useState } from 'react';
import { Key, Download, Upload, AlertCircle, CheckCircle2 } from 'lucide-react';
import { generateWallet, importFromPrivateKey, importFromSeedPhrase } from '../utils/wallet';

interface SetupWizardProps {
  onComplete: (keys: { privateKey: string; publicKey: string }) => void;
}

export default function SetupWizard({ onComplete }: SetupWizardProps) {
  const [step, setStep] = useState<'choose' | 'import' | 'generate' | 'backup'>('choose');
  const [privateKey, setPrivateKey] = useState('');
  const [seedPhrase, setSeedPhrase] = useState('');
  const [generatedKeys, setGeneratedKeys] = useState<any>(null);
  const [backupConfirmed, setBackupConfirmed] = useState(false);
  const [error, setError] = useState('');

  const handleImportPrivateKey = async () => {
    if (!privateKey || privateKey.length < 64) {
      setError('Invalid private key. Must be 64+ characters hex string.');
      return;
    }

    try {
      setError('');
      const wallet = importFromPrivateKey(privateKey.trim());
      onComplete({
        privateKey: wallet.privateKey,
        publicKey: wallet.publicKey,
      });
    } catch (err: any) {
      setError(err.message || 'Failed to import private key');
    }
  };

  const handleImportSeedPhrase = async () => {
    const words = seedPhrase.trim().split(/\s+/);
    if (words.length !== 12 && words.length !== 24) {
      setError('Invalid seed phrase. Must be 12 or 24 words.');
      return;
    }

    try {
      setError('');
      const wallet = importFromSeedPhrase(seedPhrase.trim());
      onComplete({
        privateKey: wallet.privateKey,
        publicKey: wallet.publicKey,
      });
    } catch (err: any) {
      setError(err.message || 'Failed to import seed phrase');
    }
  };

  const handleGenerateNew = async () => {
    try {
      setError('');
      const wallet = generateWallet();
      setGeneratedKeys({
        seed_phrase: wallet.seedPhrase,
        private_key: wallet.privateKey,
        public_key: wallet.publicKey,
        address: wallet.address,
      });
      setStep('backup');
    } catch (err: any) {
      setError(err.message || 'Failed to generate keys');
    }
  };

  const handleConfirmBackup = () => {
    if (!backupConfirmed) {
      setError('You must confirm that you have backed up your seed phrase!');
      return;
    }
    onComplete({
      privateKey: generatedKeys.private_key,
      publicKey: generatedKeys.public_key,
    });
  };

  const downloadBackup = () => {
    const backup = JSON.stringify(
      {
        seed_phrase: generatedKeys.seed_phrase,
        private_key: generatedKeys.private_key,
        public_key: generatedKeys.public_key,
        address: generatedKeys.address,
        created_at: new Date().toISOString(),
      },
      null,
      2
    );

    const blob = new Blob([backup], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `unauthority-validator-backup-${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-blue-900 to-purple-900 flex items-center justify-center p-6">
      <div className="bg-gray-800 rounded-2xl shadow-2xl max-w-2xl w-full p-8 border border-gray-700">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-blue-500/20 rounded-full mb-4">
            <Key className="w-8 h-8 text-blue-400" />
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">Validator Setup</h1>
          <p className="text-gray-400">Initialize your Unauthority validator node</p>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-lg flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
            <p className="text-red-200 text-sm">{error}</p>
          </div>
        )}

        {/* Choose Method */}
        {step === 'choose' && (
          <div className="space-y-4">
            <button
              onClick={() => setStep('import')}
              className="w-full p-6 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors text-left group"
            >
              <div className="flex items-center gap-4">
                <div className="p-3 bg-blue-500/20 rounded-lg group-hover:bg-blue-500/30 transition-colors">
                  <Upload className="w-6 h-6 text-blue-400" />
                </div>
                <div>
                  <h3 className="text-white font-semibold text-lg">Import Existing Keys</h3>
                  <p className="text-gray-400 text-sm">Use your existing private key or seed phrase</p>
                </div>
              </div>
            </button>

            <button
              onClick={handleGenerateNew}
              className="w-full p-6 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors text-left group"
            >
              <div className="flex items-center gap-4">
                <div className="p-3 bg-purple-500/20 rounded-lg group-hover:bg-purple-500/30 transition-colors">
                  <Key className="w-6 h-6 text-purple-400" />
                </div>
                <div>
                  <h3 className="text-white font-semibold text-lg">Generate New Keys</h3>
                  <p className="text-gray-400 text-sm">Create a new validator identity</p>
                </div>
              </div>
            </button>
          </div>
        )}

        {/* Import Keys */}
        {step === 'import' && (
          <div className="space-y-6">
            <div>
              <label className="block text-white font-medium mb-2">Private Key (Hex)</label>
              <textarea
                value={privateKey}
                onChange={(e) => setPrivateKey(e.target.value)}
                placeholder="Enter your private key..."
                className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/50 outline-none resize-none"
                rows={3}
              />
            </div>

            <div className="text-center text-gray-400">OR</div>

            <div>
              <label className="block text-white font-medium mb-2">Seed Phrase (12 or 24 words)</label>
              <textarea
                value={seedPhrase}
                onChange={(e) => setSeedPhrase(e.target.value)}
                placeholder="Enter your seed phrase..."
                className="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/50 outline-none resize-none"
                rows={3}
              />
            </div>

            <div className="flex gap-4">
              <button
                onClick={() => setStep('choose')}
                className="flex-1 px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
              >
                Back
              </button>
              <button
                onClick={privateKey ? handleImportPrivateKey : handleImportSeedPhrase}
                disabled={!privateKey && !seedPhrase}
                className="flex-1 px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Import & Start Node
              </button>
            </div>
          </div>
        )}

        {/* Backup Keys */}
        {step === 'backup' && generatedKeys && (
          <div className="space-y-6">
            <div className="p-6 bg-yellow-500/10 border border-yellow-500/50 rounded-lg">
              <div className="flex items-start gap-3 mb-4">
                <AlertCircle className="w-6 h-6 text-yellow-400 flex-shrink-0 mt-0.5" />
                <div>
                  <h3 className="text-yellow-400 font-semibold text-lg mb-2">CRITICAL: Backup Your Keys</h3>
                  <p className="text-yellow-200 text-sm">
                    Write down your seed phrase and store it in a safe place. You will need it to recover your
                    validator if you lose access.
                  </p>
                </div>
              </div>
            </div>

            <div>
              <label className="block text-white font-medium mb-2">Your Seed Phrase</label>
              <div className="p-4 bg-gray-900 border border-gray-700 rounded-lg">
                <p className="text-white font-mono text-sm leading-relaxed">{generatedKeys.seed_phrase}</p>
              </div>
            </div>

            <div>
              <label className="block text-white font-medium mb-2">Validator Address</label>
              <div className="p-4 bg-gray-900 border border-gray-700 rounded-lg">
                <p className="text-blue-400 font-mono text-sm break-all">{generatedKeys.address}</p>
              </div>
            </div>

            <button
              onClick={downloadBackup}
              className="w-full px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors flex items-center justify-center gap-2"
            >
              <Download className="w-5 h-5" />
              Download Backup File
            </button>

            <label className="flex items-center gap-3 p-4 bg-gray-700/50 rounded-lg cursor-pointer hover:bg-gray-700 transition-colors">
              <input
                type="checkbox"
                checked={backupConfirmed}
                onChange={(e) => setBackupConfirmed(e.target.checked)}
                className="w-5 h-5 rounded border-gray-600 text-blue-600 focus:ring-2 focus:ring-blue-500"
              />
              <span className="text-white text-sm">
                I have written down my seed phrase and stored it in a safe place. I understand that if I lose it, I
                will not be able to recover my validator.
              </span>
            </label>

            <button
              onClick={handleConfirmBackup}
              disabled={!backupConfirmed}
              className="w-full px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <CheckCircle2 className="w-5 h-5" />
              Confirm & Start Validator
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
