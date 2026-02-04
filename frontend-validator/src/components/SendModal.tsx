import { useState } from 'react';
import { X, Send, Loader2 } from 'lucide-react';
import { sendTransaction } from '../utils/api';

interface SendModalProps {
  isOpen: boolean;
  onClose: () => void;
  fromAddress: string | null;
}

export default function SendModal({ isOpen, onClose, fromAddress }: SendModalProps) {
  const [toAddress, setToAddress] = useState('');
  const [amount, setAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  if (!isOpen) return null;

  const handleSend = async () => {
    setError('');
    setSuccess('');

    if (!fromAddress) {
      setError('No validator address set. Please set your address in Settings.');
      return;
    }

    if (!toAddress || !amount) {
      setError('Please fill in all fields');
      return;
    }

    const amountNum = parseFloat(amount);
    if (isNaN(amountNum) || amountNum <= 0) {
      setError('Invalid amount');
      return;
    }

    setLoading(true);

    try {
      const result = await sendTransaction({
        from: fromAddress,
        to: toAddress,
        amount: amountNum,
      });

      if (result.success) {
        setSuccess(`Transaction sent successfully! Hash: ${result.hash}`);
        setToAddress('');
        setAmount('');
        setTimeout(() => {
          onClose();
          setSuccess('');
        }, 3000);
      } else {
        setError(result.error || 'Transaction failed');
      }
    } catch (err: any) {
      setError(err.message || 'Unknown error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="bg-uat-gray border border-gray-700 rounded-xl w-full max-w-md p-6 shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <Send className="w-6 h-6 text-uat-cyan" />
            <h2 className="text-xl font-bold text-white">Send UAT</h2>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form */}
        <div className="space-y-4">
          {/* From Address (readonly) */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">From</label>
            <div className="bg-uat-dark/50 border border-gray-600 rounded-lg px-4 py-2">
              <p className="font-mono text-sm text-gray-400 truncate">
                {fromAddress || 'Not set'}
              </p>
            </div>
          </div>

          {/* To Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">To Address</label>
            <input
              type="text"
              value={toAddress}
              onChange={(e) => setToAddress(e.target.value)}
              placeholder="UAT1..."
              className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-uat-blue"
            />
          </div>

          {/* Amount */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Amount (UAT)</label>
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              step="0.01"
              min="0"
              className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-uat-blue"
            />
          </div>

          {/* Error */}
          {error && (
            <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3">
              <p className="text-sm text-red-400">{error}</p>
            </div>
          )}

          {/* Success */}
          {success && (
            <div className="bg-green-500/10 border border-green-500/50 rounded-lg p-3">
              <p className="text-sm text-green-400">{success}</p>
            </div>
          )}

          {/* Actions */}
          <div className="flex space-x-3 pt-2">
            <button
              onClick={onClose}
              className="flex-1 bg-gray-700 hover:bg-gray-600 text-white font-medium py-2 px-4 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSend}
              disabled={loading}
              className="flex-1 bg-gradient-to-r from-uat-blue to-uat-cyan hover:opacity-90 text-white font-medium py-2 px-4 rounded-lg transition-opacity disabled:opacity-50 flex items-center justify-center space-x-2"
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Sending...</span>
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Send</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
