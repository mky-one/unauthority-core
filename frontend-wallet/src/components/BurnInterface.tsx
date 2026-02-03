import { useState } from 'react';
import { Flame, Bitcoin, } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';
import { submitBurn } from '../utils/api';

interface Props {
  nodeOnline: boolean;
  oraclePrices: { eth: number; btc: number } | null;
}

export default function BurnInterface({ nodeOnline, oraclePrices }: Props) {
  const [coinType, setCoinType] = useState<'btc' | 'eth'>('btc');
  const [txid, setTxid] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  // Burn addresses (user burns BTC/ETH to these addresses)
  const BTC_BURN_ADDRESS = '1BitcoinEaterAddressDontSendf59kuE'; // Example, replace with real
  const ETH_BURN_ADDRESS = '0x000000000000000000000000000000000000dEaD';

  const handleSubmitBurn = async () => {
    if (!txid.trim()) {
      setResult({ status: 'error', message: 'Please enter transaction ID' });
      return;
    }

    setLoading(true);
    setResult(null);

    try {
      const response = await submitBurn({ coin_type: coinType, txid: txid.trim() });
      setResult(response);
    } catch (error: any) {
      setResult({ status: 'error', message: error.message });
    } finally {
      setLoading(false);
    }
  };

  const estimateUAT = (amount: number): number => {
    if (!oraclePrices) return 0;
    
    const price = coinType === 'btc' ? oraclePrices.btc : oraclePrices.eth;
    const usdValue = amount * price;
    
    // 1 UAT = $0.01 USD
    return usdValue / 0.01;
  };

  return (
    <div className="max-w-4xl mx-auto p-6">
      <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8">
        <div className="flex items-center space-x-3 mb-6">
          <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-red-600 rounded-xl flex items-center justify-center">
            <Flame className="w-6 h-6 text-white" />
          </div>
          <div>
            <h2 className="text-2xl font-bold">Burn to Mint UAT</h2>
            <p className="text-sm text-gray-400">Burn BTC or ETH to receive UAT tokens</p>
          </div>
        </div>

        {/* Coin Type Selector */}
        <div className="flex space-x-4 mb-6">
          <button
            onClick={() => setCoinType('btc')}
            className={`flex-1 py-4 rounded-xl font-semibold transition-all flex items-center justify-center space-x-2 ${
              coinType === 'btc'
                ? 'bg-gradient-to-r from-orange-500 to-yellow-600 text-white shadow-lg'
                : 'bg-uat-dark border border-gray-600 text-gray-400 hover:text-white'
            }`}
          >
            <Bitcoin className="w-5 h-5" />
            <span>Bitcoin (BTC)</span>
          </button>
          
          <button
            onClick={() => setCoinType('eth')}
            className={`flex-1 py-4 rounded-xl font-semibold transition-all flex items-center justify-center space-x-2 ${
              coinType === 'eth'
                ? 'bg-gradient-to-r from-purple-500 to-blue-600 text-white shadow-lg'
                : 'bg-uat-dark border border-gray-600 text-gray-400 hover:text-white'
            }`}
          >
            <span className="text-xl">Ξ</span>
            <span>Ethereum (ETH)</span>
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          {/* Step 1: Send Coins */}
          <div className="bg-uat-dark border border-gray-600 rounded-xl p-6">
            <h3 className="font-semibold mb-3 flex items-center space-x-2">
              <span className="w-6 h-6 bg-uat-blue rounded-full flex items-center justify-center text-sm">1</span>
              <span>Send {coinType.toUpperCase()} to Burn Address</span>
            </h3>
            
            <div className="bg-white p-4 rounded-lg mb-4 flex justify-center">
              <QRCodeSVG
                value={coinType === 'btc' ? BTC_BURN_ADDRESS : ETH_BURN_ADDRESS}
                size={180}
                level="H"
                includeMargin
              />
            </div>

            <div className="bg-uat-gray rounded-lg p-3">
              <p className="text-xs text-gray-400 mb-1">Burn Address:</p>
              <code className="text-xs font-mono break-all">
                {coinType === 'btc' ? BTC_BURN_ADDRESS : ETH_BURN_ADDRESS}
              </code>
            </div>

            {oraclePrices && (
              <div className="mt-4 text-xs text-gray-400">
                <p>Current Price: ${(coinType === 'btc' ? oraclePrices.btc : oraclePrices.eth).toLocaleString()}</p>
                <p className="mt-1">Example: 0.01 {coinType.toUpperCase()} = {estimateUAT(0.01).toLocaleString()} UAT</p>
              </div>
            )}
          </div>

          {/* Step 2: Submit TXID */}
          <div className="bg-uat-dark border border-gray-600 rounded-xl p-6">
            <h3 className="font-semibold mb-3 flex items-center space-x-2">
              <span className="w-6 h-6 bg-uat-blue rounded-full flex items-center justify-center text-sm">2</span>
              <span>Submit Transaction ID</span>
            </h3>

            <div className="mb-4">
              <label className="block text-sm text-gray-400 mb-2">Transaction ID (TXID)</label>
              <input
                type="text"
                value={txid}
                onChange={(e) => setTxid(e.target.value)}
                placeholder={coinType === 'btc' ? '2096b844178ecc776e050be...' : '0x459ccd6fe488b0f826aef19...'}
                className="w-full bg-uat-gray border border-gray-600 rounded-lg px-4 py-3 text-sm font-mono focus:ring-2 focus:ring-uat-blue focus:border-transparent"
                disabled={!nodeOnline}
              />
            </div>

            <button
              onClick={handleSubmitBurn}
              disabled={loading || !nodeOnline}
              className={`w-full py-3 rounded-xl font-semibold transition-all ${
                loading || !nodeOnline
                  ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
                  : 'bg-gradient-to-r from-uat-blue to-uat-cyan text-white hover:shadow-lg'
              }`}
            >
              {loading ? 'Verifying...' : 'Submit Burn Transaction'}
            </button>

            <div className="mt-4 text-xs text-gray-400 space-y-1">
              <p>• Wait for blockchain confirmations (6+ for BTC, 12+ for ETH)</p>
              <p>• Validators will verify your burn automatically</p>
              <p>• UAT will be minted to your wallet address</p>
            </div>
          </div>
        </div>

        {/* Result Display */}
        {result && (
          <div className={`mt-6 p-4 rounded-xl border ${
            result.status === 'success'
              ? 'bg-green-500/10 border-green-500/30'
              : 'bg-red-500/10 border-red-500/30'
          }`}>
            <h4 className={`font-semibold mb-2 ${
              result.status === 'success' ? 'text-green-400' : 'text-red-400'
            }`}>
              {result.status === 'success' ? '✅ Burn Submitted' : '❌ Error'}
            </h4>
            <p className="text-sm">
              {result.message || result.msg || result.error}
            </p>
            {result.initial_power !== undefined && (
              <p className="text-xs text-gray-400 mt-2">
                Voting power: {result.initial_power} | Waiting for validator consensus...
              </p>
            )}
          </div>
        )}

        {!nodeOnline && (
          <div className="mt-6 bg-red-500/10 border border-red-500/30 rounded-xl p-4 text-center">
            <p className="text-red-400">⚠️ Node offline - Start your node to submit burns</p>
          </div>
        )}

        {/* Info Box */}
        <div className="mt-6 bg-blue-500/10 border border-blue-500/30 rounded-xl p-4">
          <h4 className="font-semibold text-blue-400 mb-2">How Proof-of-Burn Works:</h4>
          <ol className="text-sm text-blue-200 space-y-1 list-decimal list-inside">
            <li>Send BTC/ETH to the burn address (coins are destroyed permanently)</li>
            <li>Submit your transaction ID to the network</li>
            <li>Validators verify the burn on Bitcoin/Ethereum blockchain</li>
            <li>UAT tokens are minted based on oracle price consensus</li>
            <li>Bonding curve ensures fair distribution (early burns get more UAT)</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
