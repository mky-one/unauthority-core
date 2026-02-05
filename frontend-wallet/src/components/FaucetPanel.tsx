/**
 * Testnet Faucet Component
 * Allows users to request free testnet UAT tokens
 */

import { useState, useEffect } from 'react';
import { Droplet, Loader2, CheckCircle2, AlertCircle, Clock } from 'lucide-react';
import { useWalletStore } from '../store/walletStore';
import { claimFaucet } from '../utils/api';

export default function FaucetPanel() {
  const { wallet } = useWalletStore();
  const [isRequesting, setIsRequesting] = useState(false);
  const [result, setResult] = useState<{ type: 'success' | 'error' | 'info'; message: string } | null>(null);
  const [cooldownSeconds, setCooldownSeconds] = useState(0);

  // Cooldown timer
  useEffect(() => {
    if (cooldownSeconds > 0) {
      const timer = setInterval(() => {
        setCooldownSeconds((prev) => Math.max(0, prev - 1));
      }, 1000);
      return () => clearInterval(timer);
    }
  }, [cooldownSeconds]);

  const formatCooldown = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours}h ${minutes}m ${secs}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${secs}s`;
    } else {
      return `${secs}s`;
    }
  };

  const handleClaim = async () => {
    if (!wallet) {
      setResult({ type: 'error', message: 'No wallet loaded. Please create or import a wallet first.' });
      return;
    }

    setIsRequesting(true);
    setResult(null);

    try {
      const response = await claimFaucet(wallet.address);
      
      if (response.status === 'success') {
        setResult({
          type: 'success',
          message: `Success! Received ${response.amount_uat} UAT. Check your balance in a few seconds.`,
        });
        
        // Set cooldown (1 hour = 3600 seconds)
        setCooldownSeconds(3600);
      } else {
        const errorMsg = response.error || response.msg || 'Failed to claim tokens';
        
        // Parse cooldown from error message
        const cooldownMatch = errorMsg.match(/(\d+)\s*seconds?/i);
        if (cooldownMatch) {
          const seconds = parseInt(cooldownMatch[1]);
          setCooldownSeconds(seconds);
          setResult({
            type: 'info',
            message: `Cooldown active. Try again in ${formatCooldown(seconds)}.`,
          });
        } else {
          setResult({
            type: 'error',
            message: errorMsg,
          });
        }
      }
    } catch (error: any) {
      setResult({
        type: 'error',
        message: error.message || 'Network error. Make sure the node is running.',
      });
    } finally {
      setIsRequesting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8">
        {/* Header */}
        <div className="flex items-center space-x-3 mb-6">
          <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-cyan-500 rounded-xl flex items-center justify-center">
            <Droplet className="w-6 h-6 text-white" />
          </div>
          <div>
            <h2 className="text-2xl font-bold">💧 Testnet Faucet</h2>
            <p className="text-sm text-gray-400">Get free test UAT tokens</p>
          </div>
        </div>

        {/* Description */}
        <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-4 mb-6">
          <p className="text-sm text-blue-200">
            Request free testnet UAT tokens for development and testing. 
            Limited to <strong>100 UAT per hour</strong> per address.
          </p>
        </div>

        {/* Wallet Address Display */}
        {wallet && (
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Your Testnet Address:
            </label>
            <div className="bg-gray-800 border border-gray-700 rounded-lg p-4">
              <code className="text-sm text-white font-mono break-all">
                {wallet.address}
              </code>
            </div>
          </div>
        )}

        {/* Result Messages */}
        {result && (
          <div className={`mb-6 p-4 rounded-lg flex items-start space-x-3 ${
            result.type === 'success' ? 'bg-green-900/30 border border-green-700' :
            result.type === 'error' ? 'bg-red-900/30 border border-red-700' :
            'bg-yellow-900/30 border border-yellow-700'
          }`}>
            {result.type === 'success' && <CheckCircle2 className="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" />}
            {result.type === 'error' && <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />}
            {result.type === 'info' && <Clock className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />}
            <p className={`text-sm ${
              result.type === 'success' ? 'text-green-200' :
              result.type === 'error' ? 'text-red-200' :
              'text-yellow-200'
            }`}>
              {result.message}
            </p>
          </div>
        )}

        {/* Cooldown Timer */}
        {cooldownSeconds > 0 && (
          <div className="mb-6 bg-yellow-900/20 border border-yellow-700 rounded-lg p-4">
            <div className="flex items-center space-x-2 text-yellow-300">
              <Clock className="w-5 h-5" />
              <span className="text-sm font-medium">
                Cooldown: {formatCooldown(cooldownSeconds)}
              </span>
            </div>
          </div>
        )}

        {/* Claim Button */}
        <button
          onClick={handleClaim}
          disabled={isRequesting || !wallet || cooldownSeconds > 0}
          className="w-full bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 
                     disabled:from-gray-700 disabled:to-gray-700 disabled:cursor-not-allowed 
                     text-white font-medium py-4 rounded-xl transition-all duration-200 
                     flex items-center justify-center space-x-2"
        >
          {isRequesting ? (
            <>
              <Loader2 className="w-5 h-5 animate-spin" />
              <span>Requesting Tokens...</span>
            </>
          ) : cooldownSeconds > 0 ? (
            <span>Cooldown Active ({formatCooldown(cooldownSeconds)})</span>
          ) : (
            <>
              <Droplet className="w-5 h-5" />
              <span>Request 100 UAT</span>
            </>
          )}
        </button>

        {/* Warning */}
        <div className="mt-6 p-4 bg-gray-800 border border-gray-700 rounded-lg">
          <p className="text-xs text-gray-400 text-center">
            ⚠️ <strong>Testnet Only</strong> - These tokens have no real value and cannot be traded.
          </p>
        </div>

        {/* Help Text */}
        <div className="mt-4 text-center">
          <p className="text-xs text-gray-500">
            Need more tokens? Join our{' '}
            <a href="https://discord.gg/unauthority" target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:underline">
              Discord
            </a>
            {' '}and ask in #testnet-faucet
          </p>
        </div>
      </div>
    </div>
  );
}
