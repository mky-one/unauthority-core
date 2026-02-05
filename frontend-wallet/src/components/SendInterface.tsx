import { useState } from 'react';
import { Send, AlertCircle } from 'lucide-react';
import { useWalletStore } from '../store/walletStore';
import { sendTransaction } from '../utils/api';
import { isValidUATAddress, formatBalance, signTransaction } from '../utils/wallet';

interface Props {
  nodeOnline: boolean;
}

export default function SendInterface({ nodeOnline }: Props) {
  const { wallet, balance } = useWalletStore();
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  const handleSend = async () => {
    setResult(null);

    // Validation
    if (!recipient.trim()) {
      setResult({ status: 'error', message: 'Please enter recipient address' });
      return;
    }

    if (!isValidUATAddress(recipient.trim())) {
      setResult({ status: 'error', message: 'Invalid UAT address format' });
      return;
    }

    const amountNum = parseFloat(amount);
    if (isNaN(amountNum) || amountNum <= 0) {
      setResult({ status: 'error', message: 'Invalid amount' });
      return;
    }

    // Balance is already in UAT, compare directly
    if (amountNum > balance) {
      setResult({ status: 'error', message: 'Insufficient balance' });
      return;
    }

    setLoading(true);

    try {
      // Get current account state for previous hash
      const { getApiUrl } = await import('../utils/api');
      const accountData = await fetch(`${getApiUrl()}/account/${wallet!.address}`);
      const accountJson = await accountData.json();
      const previous = accountJson.head || '0';
      
      // Convert UAT to VOI for block amount
      const amountVoi = Math.floor(amountNum * 100_000_000);
      
      // Sign transaction client-side
      const signature = await signTransaction(
        wallet!.privateKey,
        wallet!.address,
        previous,
        'Send',
        amountVoi,
        recipient.trim()
      );
      
      console.log('Signing transaction:', {
        from: wallet!.address,
        to: recipient.trim(),
        amount: amountNum,
        previous,
        signature: signature.slice(0, 16) + '...'
      });
      
      // Send signed transaction to backend
      const response = await sendTransaction(
        wallet!.address,
        recipient.trim(),
        amountNum
      );
      
      console.log('Transaction sent:', response);

      setResult({
        status: 'success',
        message: `Successfully sent ${amount} UAT to ${recipient.slice(0, 12)}...`,
      });
      
      // Clear form
      setRecipient('');
      setAmount('');
    } catch (error: any) {
      console.error('Send error:', error);
      setResult({ status: 'error', message: error.message });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8">
        <div className="flex items-center space-x-3 mb-6">
          <div className="w-12 h-12 bg-gradient-to-br from-uat-blue to-uat-cyan rounded-xl flex items-center justify-center">
            <Send className="w-6 h-6 text-white" />
          </div>
          <div>
            <h2 className="text-2xl font-bold">Send UAT</h2>
            <p className="text-sm text-gray-400">Transfer UAT to another address</p>
          </div>
        </div>

        {/* Balance Display */}
        <div className="bg-uat-dark border border-gray-600 rounded-xl p-4 mb-6">
          <p className="text-sm text-gray-400">Available Balance</p>
          <p className="text-3xl font-bold mt-1">{formatBalance(balance)} UAT</p>
        </div>

        {/* Recipient Address */}
        <div className="mb-4">
          <label className="block text-sm font-medium mb-2">Recipient Address</label>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            placeholder="UAT..."
            className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-3 text-sm font-mono focus:ring-2 focus:ring-uat-blue focus:border-transparent"
            disabled={!nodeOnline}
          />
        </div>

        {/* Amount */}
        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">Amount (UAT)</label>
          <div className="relative">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              step="0.01"
              min="0"
              className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-3 text-sm focus:ring-2 focus:ring-uat-blue focus:border-transparent"
              disabled={!nodeOnline}
            />
            <button
              onClick={() => setAmount(formatBalance(balance))}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-uat-blue hover:text-uat-cyan font-semibold"
              disabled={!nodeOnline}
            >
              MAX
            </button>
          </div>
        </div>

        {/* Send Button */}
        <button
          onClick={handleSend}
          disabled={loading || !nodeOnline}
          className={`w-full py-4 rounded-xl font-semibold transition-all ${
            loading || !nodeOnline
              ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
              : 'bg-gradient-to-r from-uat-blue to-uat-cyan text-white hover:shadow-lg'
          }`}
        >
          {loading ? 'Sending...' : 'Send UAT'}
        </button>

        {/* Result Display */}
        {result && (
          <div className={`mt-6 p-4 rounded-xl border ${
            result.status === 'success'
              ? 'bg-green-500/10 border-green-500/30'
              : 'bg-red-500/10 border-red-500/30'
          }`}>
            <p className={`text-sm ${
              result.status === 'success' ? 'text-green-400' : 'text-red-400'
            }`}>
              {result.message}
            </p>
          </div>
        )}

        {!nodeOnline && (
          <div className="mt-6 bg-red-500/10 border border-red-500/30 rounded-xl p-4 flex items-start space-x-2">
            <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
            <div>
              <p className="text-sm text-red-400 font-semibold">Node Offline</p>
              <p className="text-xs text-red-300 mt-1">Start your Unauthority node to send transactions</p>
            </div>
          </div>
        )}

        {/* Info */}
        <div className="mt-6 bg-blue-500/10 border border-blue-500/30 rounded-xl p-4">
          <h4 className="text-sm font-semibold text-blue-400 mb-2">Transaction Info:</h4>
          <ul className="text-xs text-blue-200 space-y-1">
            <li>• Block-Lattice: Each account has its own chain</li>
            <li>• Finality: &lt;3 seconds (aBFT consensus)</li>
            <li>• Gas Fees: Paid to validators (no inflation)</li>
            <li>• Security: Post-quantum cryptography (Dilithium)</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
