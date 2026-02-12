import { useEffect, useState } from 'react';
import { History, RefreshCw } from 'lucide-react';
import { useWalletStore } from '../store/walletStore';
import { getHistory, Transaction } from '../utils/api';
import { formatBalance } from '../utils/wallet';

export default function HistoryView() {
  const { wallet } = useWalletStore();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchHistory = async () => {
    if (!wallet) return;
    
    setLoading(true);
    try {
      const history = await getHistory(wallet.address);
      setTransactions(history);
    } catch (error) {
      console.error('Failed to fetch history:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHistory();
  }, [wallet]);

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  return (
    <div className="max-w-6xl mx-auto p-6">
      <div className="bg-los-gray border border-gray-700 rounded-2xl p-8">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 bg-gradient-to-br from-los-blue to-los-cyan rounded-xl flex items-center justify-center">
              <History className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-2xl font-bold">Transaction History</h2>
              <p className="text-sm text-gray-400">{transactions.length} transactions</p>
            </div>
          </div>

          <button
            onClick={fetchHistory}
            disabled={loading}
            className="flex items-center space-x-2 px-4 py-2 bg-los-dark border border-gray-600 rounded-lg hover:bg-gray-800 transition-all"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>

        {transactions.length === 0 ? (
          <div className="text-center py-12">
            <History className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No transactions yet</p>
            <p className="text-sm text-gray-500 mt-2">Your transaction history will appear here</p>
          </div>
        ) : (
          <div className="space-y-3">
            {transactions.map((tx, index) => (
              <div
                key={index}
                className="bg-los-dark border border-gray-600 rounded-xl p-4 hover:border-los-blue transition-all"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-2 mb-2">
                      <span className={`px-2 py-1 rounded text-xs font-semibold ${
                        tx.type === 'send' || tx.tx_type === 'send'
                          ? 'bg-red-500/20 text-red-400'
                          : tx.type === 'receive' || tx.tx_type === 'receive'
                          ? 'bg-green-500/20 text-green-400'
                          : 'bg-orange-500/20 text-orange-400'
                      }`}>
                        {(tx.type || tx.tx_type || 'transaction').toUpperCase()}
                      </span>
                      <span className="text-xs text-gray-500">{formatDate(tx.timestamp || 0)}</span>
                    </div>

                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <p className="text-gray-400 text-xs mb-1">From</p>
                        <code className="text-xs font-mono text-gray-300">{tx.from.slice(0, 20)}...</code>
                      </div>
                      <div>
                        <p className="text-gray-400 text-xs mb-1">To</p>
                        <code className="text-xs font-mono text-gray-300">{tx.to.slice(0, 20)}...</code>
                      </div>
                    </div>

                    <div className="mt-2">
                      <p className="text-gray-400 text-xs mb-1">Transaction Hash</p>
                      <code className="text-xs font-mono text-gray-500">{tx.hash}</code>
                    </div>
                  </div>

                  <div className="text-right ml-4">
                    <p className={`text-xl font-bold ${
                      (tx.type === 'receive' || tx.tx_type === 'receive') ? 'text-green-400' : 'text-red-400'
                    }`}>
                      {(tx.type === 'receive' || tx.tx_type === 'receive') ? '+' : '-'}{formatBalance(tx.amount)} LOS
                    </p>
                    <p className="text-xs text-gray-500 mt-1">
                      ≈ ${(parseFloat(formatBalance(tx.amount)) * 0.01).toFixed(2)}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
