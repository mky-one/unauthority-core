import { useEffect, useState } from 'react';
import { Copy, Eye, EyeOff, RefreshCw, Gift } from 'lucide-react';
import { useWalletStore } from '../store/walletStore';
import { formatBalance } from '../utils/wallet';
import { getNodeInfo } from '../utils/api';
import { getCurrentNetwork } from '../config/networks';

interface Props {
  nodeOnline: boolean;
  oraclePrices: { eth: number; btc: number } | null;
}

export default function Dashboard({ nodeOnline, oraclePrices }: Props) {
  const { wallet, balance, fetchBalance } = useWalletStore();
  const [showPrivateKey, setShowPrivateKey] = useState(false);
  const [copied, setCopied] = useState(false);
  const [nodeInfo, setNodeInfo] = useState<any>(null);
  const [claiming, setClaiming] = useState(false);
  const [claimSuccess, setClaimSuccess] = useState(false);

  // Balance is already in UAT (not VOI), so use directly
  const usdValue = balance * 0.01; // 1 UAT = $0.01
  console.log('Balance (UAT):', balance, 'USD Value:', usdValue, 'Oracle Prices:', oraclePrices);

  useEffect(() => {
    if (nodeOnline) {
      getNodeInfo().then(setNodeInfo);
    }
  }, [nodeOnline]);

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const claimFaucet = async () => {
    if (!wallet || claiming) return;
    
    setClaiming(true);
    try {
      const response = await fetch('http://localhost:3030/faucet', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ address: wallet.address })
      });
      
      const result = await response.json();
      
      if (result.status === 'success') {
        setClaimSuccess(true);
        setTimeout(() => setClaimSuccess(false), 3000);
        // Refresh balance after successful claim
        await fetchBalance(wallet.address);
        alert('✅ Faucet claimed successfully! +100,000 UAT');
      } else {
        alert(`❌ Faucet claim failed: ${result.msg || 'Unknown error'}`);
      }
    } catch (error) {
      console.error('Faucet error:', error);
      alert('Failed to claim faucet. Is the node running?');
    } finally {
      setClaiming(false);
    }
  };

  if (!wallet) return null;

  return (
    <div className="max-w-6xl mx-auto p-6">
      {/* Balance Card */}
      <div className="bg-gradient-to-br from-uat-blue to-uat-cyan rounded-2xl p-8 mb-6 text-white shadow-xl">
        <div className="flex items-center justify-between mb-4">
          <div>
            <p className="text-sm opacity-90">Total Balance</p>
            <h2 className="text-5xl font-bold mt-2">{formatBalance(balance)} UAT</h2>
            <p className="text-sm opacity-75 mt-2">≈ ${(parseFloat(formatBalance(balance)) * 0.01).toFixed(2)} USD</p>
          </div>
          <div className="flex space-x-2">
            <button 
              onClick={() => wallet && fetchBalance(wallet.address)}
              className="p-3 bg-white/20 rounded-full hover:bg-white/30 transition-all"
              title="Refresh Balance"
            >
              <RefreshCw className="w-6 h-6" />
            </button>
            {getCurrentNetwork().faucetEnabled && (
              <button 
                onClick={claimFaucet}
                disabled={claiming || !nodeOnline}
                className={`p-3 rounded-full transition-all ${
                  claimSuccess 
                    ? 'bg-green-500/30 text-green-400' 
                    : claiming 
                    ? 'bg-gray-500/30 cursor-wait' 
                    : 'bg-white/20 hover:bg-white/30'
                }`}
                title={claimSuccess ? 'Claimed!' : claiming ? 'Claiming...' : 'Claim 100,000 UAT (Testnet Only)'}
              >
                {claimSuccess ? <span className="text-2xl">✓</span> : <Gift className="w-6 h-6" />}
              </button>
            )}
          </div>
        </div>
        {claimSuccess && (
          <div className="bg-green-500/20 border border-green-500/40 rounded-lg p-3 text-sm">
            🎉 Successfully claimed 100,000 UAT from faucet!
          </div>
        )}
      </div>

      {/* Wallet Info */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        <div className="bg-uat-gray border border-gray-700 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Wallet Address</h3>
          <div className="flex items-center justify-between bg-uat-dark rounded-lg p-3">
            <code className="text-sm text-gray-300 font-mono truncate flex-1">{wallet.address}</code>
            <button
              onClick={() => copyToClipboard(wallet.address)}
              className="ml-2 p-2 hover:bg-gray-700 rounded transition-all"
            >
              {copied ? <span className="text-green-500 text-xs">✓</span> : <Copy className="w-4 h-4" />}
            </button>
          </div>
        </div>

        <div className="bg-uat-gray border border-gray-700 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4">Public Key</h3>
          <div className="flex items-center justify-between bg-uat-dark rounded-lg p-3">
            <code className="text-sm text-gray-300 font-mono truncate flex-1">{wallet.publicKey}</code>
            <button
              onClick={() => copyToClipboard(wallet.publicKey)}
              className="ml-2 p-2 hover:bg-gray-700 rounded transition-all"
            >
              <Copy className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Private Key (Sensitive) */}
      <div className="bg-uat-gray border border-red-500/30 rounded-xl p-6 mb-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-red-400">Private Key</h3>
          <button
            onClick={() => setShowPrivateKey(!showPrivateKey)}
            className="flex items-center space-x-2 text-sm text-gray-400 hover:text-white transition-all"
          >
            {showPrivateKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            <span>{showPrivateKey ? 'Hide' : 'Show'}</span>
          </button>
        </div>
        <div className="flex items-center justify-between bg-uat-dark rounded-lg p-3">
          {showPrivateKey ? (
            <code className="text-sm text-gray-300 font-mono truncate flex-1">{wallet.privateKey}</code>
          ) : (
            <span className="text-sm text-gray-500">••••••••••••••••••••••••••••</span>
          )}
          {showPrivateKey && (
            <button
              onClick={() => copyToClipboard(wallet.privateKey)}
              className="ml-2 p-2 hover:bg-gray-700 rounded transition-all"
            >
              <Copy className="w-4 h-4" />
            </button>
          )}
        </div>
        <p className="text-xs text-red-400 mt-2">⚠️ Never share your private key with anyone!</p>
      </div>

      {/* Network Stats */}
      {nodeInfo && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-uat-gray border border-gray-700 rounded-xl p-6">
            <p className="text-sm text-gray-400 mb-1">Total Supply</p>
            <p className="text-2xl font-bold">{(nodeInfo.total_supply || 21936236).toLocaleString()} UAT</p>
          </div>
          
          <div className="bg-uat-gray border border-gray-700 rounded-xl p-6">
            <p className="text-sm text-gray-400 mb-1">Circulating Supply</p>
            <p className="text-2xl font-bold">{(nodeInfo.circulating_supply || 0).toLocaleString()} UAT</p>
          </div>
          
          <div className="bg-uat-gray border border-gray-700 rounded-xl p-6">
            <p className="text-sm text-gray-400 mb-1">Total Burned (BTC/ETH)</p>
            <p className="text-2xl font-bold">{nodeInfo.total_burned_usd ? `$${(nodeInfo.total_burned_usd / 100).toLocaleString()}` : '$0'}</p>
          </div>
        </div>
      )}

      {!nodeOnline && (
        <div className="mt-6 bg-red-500/10 border border-red-500/30 rounded-xl p-4 text-center">
          <p className="text-red-400">⚠️ Node offline - Start your Unauthority node to see live data</p>
          <code className="text-xs text-gray-400 mt-2 block">./target/release/uat-node 3030</code>
        </div>
      )}
    </div>
  );
}
