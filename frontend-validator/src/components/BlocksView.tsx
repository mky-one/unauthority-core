import { useState, useEffect } from 'react';
import { getRecentBlocks, Block } from '../utils/api';
import { formatTimestamp } from '../utils/format';
import { Box } from 'lucide-react';

export default function BlocksView() {
  const [blocks, setBlocks] = useState<Block[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchBlocks = async () => {
      setLoading(true);
      const data = await getRecentBlocks();
      setBlocks(data);
      setLoading(false);
    };

    fetchBlocks();
    const interval = setInterval(fetchBlocks, 15000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="bg-los-gray border border-gray-700 rounded-xl p-8 text-center">
        <p className="text-gray-400">Loading blocks...</p>
      </div>
    );
  }

  if (blocks.length === 0) {
    return (
      <div className="bg-los-gray border border-gray-700 rounded-xl p-8 text-center">
        <Box className="w-12 h-12 text-gray-500 mx-auto mb-4" />
        <p className="text-gray-400">No recent blocks found.</p>
      </div>
    );
  }

  return (
    <div className="bg-los-gray border border-gray-700 rounded-xl overflow-hidden">
      <div className="p-6 border-b border-gray-700">
        <h3 className="text-lg font-semibold text-white">Recent Blocks</h3>
        <p className="text-sm text-gray-400 mt-1">Latest finalized blocks on the network</p>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-slate-900">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Height
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Hash
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Transactions
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Timestamp
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-700">
            {blocks.map((block, index) => (
              <tr key={index} className="hover:bg-slate-900/50 transition-colors">
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="text-sm font-medium text-white">#{block.height}</span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <code className="text-xs text-gray-300">
                    {block.hash.slice(0, 16)}...
                  </code>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="text-sm text-gray-300">{block.transactions_count}</span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="text-xs text-gray-400">{formatTimestamp(block.timestamp)}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
