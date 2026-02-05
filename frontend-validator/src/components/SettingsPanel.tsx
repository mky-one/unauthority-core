import { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Globe, Wallet, Save, RefreshCw } from 'lucide-react';
import { useValidatorStore } from '../store/validatorStore';
import { getWhoami } from '../utils/api';

export default function SettingsPanel() {
  const { ownAddress, setOwnAddress } = useValidatorStore();
  const [apiEndpoint, setApiEndpoint] = useState('http://localhost:3030');
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [refreshInterval, setRefreshInterval] = useState(10);
  const [localAddress, setLocalAddress] = useState(ownAddress || '');
  const [isLoadingAddress, setIsLoadingAddress] = useState(false);

  useEffect(() => {
    if (ownAddress) {
      setLocalAddress(ownAddress);
    }
  }, [ownAddress]);
  
  const handleFetchNodeAddress = async () => {
    setIsLoadingAddress(true);
    try {
      const whoami = await getWhoami();
      if (whoami) {
        setLocalAddress(whoami.address || '');
        setOwnAddress(whoami.address || '');
        alert(`✅ Node address fetched: ${whoami.short || whoami.address || 'Unknown'}`);
      } else {
        alert('❌ Failed to fetch node address');
      }
    } catch (error) {
      alert('❌ Error fetching node address');
    } finally {
      setIsLoadingAddress(false);
    }
  };

  const handleSave = () => {
    if (localAddress) {
      setOwnAddress(localAddress);
      alert('Settings saved successfully!');
    } else {
      alert('Settings saved!');
    }
  };

  return (
    <div className="max-w-2xl">
      <div className="bg-uat-gray border border-gray-700 rounded-xl p-6 space-y-6">
        <div className="flex items-center space-x-3 pb-4 border-b border-gray-700">
          <SettingsIcon className="w-6 h-6 text-uat-blue" />
          <h3 className="text-lg font-semibold text-white">Dashboard Settings</h3>
        </div>

        {/* API Endpoint */}
        <div>
          <label className="flex items-center space-x-2 text-sm font-medium text-gray-300 mb-2">
            <Globe className="w-4 h-4" />
            <span>API Endpoint</span>
          </label>
          <input
            type="text"
            value={apiEndpoint}
            onChange={(e) => setApiEndpoint(e.target.value)}
            placeholder="http://localhost:3030"
            className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-uat-blue"
          />
          <p className="text-xs text-gray-400 mt-1">The REST API endpoint of your validator node</p>
        </div>

        {/* Validator Address */}
        <div>
          <label className="flex items-center space-x-2 text-sm font-medium text-gray-300 mb-2">
            <Wallet className="w-4 h-4" />
            <span>Your Validator Address</span>
          </label>
          <div className="flex space-x-2">
            <input
              type="text"
              value={localAddress}
              onChange={(e) => setLocalAddress(e.target.value)}
              placeholder="Click 'Fetch from Node' to auto-fill..."
              className="flex-1 bg-uat-dark border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-uat-blue font-mono text-sm"
            />
            <button
              onClick={handleFetchNodeAddress}
              disabled={isLoadingAddress}
              className="flex items-center space-x-2 px-4 py-2 bg-uat-blue hover:bg-uat-blue/80 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${isLoadingAddress ? 'animate-spin' : ''}`} />
              <span className="font-medium">Fetch from Node</span>
            </button>
          </div>
          <p className="text-xs text-gray-400 mt-1">
            Click "Fetch from Node" to automatically get your node's internal signing address from /whoami endpoint
          </p>
        </div>

        {/* Auto Refresh */}
        <div>
          <label className="flex items-center space-x-3 cursor-pointer">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              className="w-4 h-4 text-uat-blue bg-uat-dark border-gray-600 rounded focus:ring-uat-blue"
            />
            <span className="text-sm font-medium text-gray-300">Auto-refresh data</span>
          </label>
        </div>

        {/* Refresh Interval */}
        {autoRefresh && (
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Refresh Interval (seconds)
            </label>
            <input
              type="number"
              value={refreshInterval}
              onChange={(e) => setRefreshInterval(parseInt(e.target.value))}
              min="5"
              max="60"
              className="w-full bg-uat-dark border border-gray-600 rounded-lg px-4 py-2 text-white focus:outline-none focus:border-uat-blue"
            />
          </div>
        )}

        {/* Save Button */}
        <div className="pt-4">
          <button
            onClick={handleSave}
            className="w-full bg-gradient-to-r from-uat-blue to-uat-cyan hover:opacity-90 text-white font-medium py-3 rounded-lg transition-opacity flex items-center justify-center space-x-2"
          >
            <Save className="w-4 h-4" />
            <span>Save Settings</span>
          </button>
        </div>
      </div>

      {/* Info */}
      <div className="mt-6 bg-blue-500/10 border border-blue-500/30 rounded-xl p-4">
        <p className="text-sm text-blue-300">
          💡 <strong>Tip:</strong> This dashboard connects to your local validator node REST API. Ensure your node is running on the configured port.
        </p>
      </div>
    </div>
  );
}
