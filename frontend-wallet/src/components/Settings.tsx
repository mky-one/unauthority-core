/**
 * Settings Component
 * Manage network endpoint, preferences, and app configuration
 */

import { useState } from 'react';
import { Settings as SettingsIcon, Wifi, Globe, Save, RotateCcw } from 'lucide-react';
import { setApiBase, getApiBaseUrl } from '../utils/api';

interface NetworkPreset {
  name: string;
  url: string;
  description: string;
}

const NETWORK_PRESETS: NetworkPreset[] = [
  {
    name: 'Local Testnet',
    url: 'http://localhost:3030',
    description: 'Your local node (default)',
  },
  {
    name: 'Ngrok Remote',
    url: 'https://YOUR_NGROK_URL.ngrok-free.app',
    description: 'Friend\'s node via Ngrok',
  },
  {
    name: 'Public Testnet',
    url: 'https://testnet.unauthority.network',
    description: 'Official public testnet',
  },
];

export default function Settings() {
  const [endpoint, setEndpoint] = useState(getApiBaseUrl());
  const [saved, setSaved] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);

  const handleSave = () => {
    setApiBase(endpoint);
    setSaved(true);
    
    setTimeout(() => {
      window.location.reload();
    }, 1500);
  };

  const handleTest = async () => {
    setTesting(true);
    setTestResult(null);

    try {
      const response = await fetch(`${endpoint}/node-info`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(5000),
      });

      if (response.ok) {
        const data = await response.json();
        setTestResult({
          success: true,
          message: `Connected! Chain: ${data.chain_name || 'UAT'}`,
        });
      } else {
        setTestResult({
          success: false,
          message: `Error: HTTP ${response.status}`,
        });
      }
    } catch (error: any) {
      setTestResult({
        success: false,
        message: `Failed: ${error.message || 'Network error'}`,
      });
    } finally {
      setTesting(false);
    }
  };

  const handleReset = () => {
    setEndpoint('http://localhost:3030');
    setSaved(false);
    setTestResult(null);
  };

  return (
    <div className="max-w-3xl mx-auto p-6">
      <div className="bg-uat-gray border border-gray-700 rounded-2xl p-8">
        {/* Header */}
        <div className="flex items-center space-x-3 mb-8">
          <div className="w-12 h-12 bg-gradient-to-br from-purple-500 to-pink-500 rounded-xl flex items-center justify-center">
            <SettingsIcon className="w-6 h-6 text-white" />
          </div>
          <div>
            <h2 className="text-2xl font-bold">Settings</h2>
            <p className="text-sm text-gray-400">Configure network and preferences</p>
          </div>
        </div>

        {/* Network Configuration */}
        <div className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Wifi className="w-5 h-5" />
              Network Configuration
            </h3>

            {/* Current Endpoint */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-400 mb-2">
                API Endpoint
              </label>
              <input
                type="text"
                value={endpoint}
                onChange={(e) => {
                  setEndpoint(e.target.value);
                  setSaved(false);
                  setTestResult(null);
                }}
                placeholder="https://testnet.unauthority.network"
                className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white focus:border-blue-500 focus:outline-none"
              />
            </div>

            {/* Test Connection Button */}
            <div className="flex gap-3 mb-4">
              <button
                onClick={handleTest}
                disabled={testing || !endpoint}
                className="flex-1 bg-gray-700 hover:bg-gray-600 disabled:bg-gray-800 disabled:cursor-not-allowed text-white py-2 rounded-lg font-medium flex items-center justify-center gap-2 transition-colors"
              >
                {testing ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    Testing...
                  </>
                ) : (
                  <>
                    <Globe className="w-4 h-4" />
                    Test Connection
                  </>
                )}
              </button>

              <button
                onClick={handleReset}
                className="px-6 bg-gray-700 hover:bg-gray-600 text-white py-2 rounded-lg font-medium flex items-center gap-2 transition-colors"
              >
                <RotateCcw className="w-4 h-4" />
                Reset
              </button>
            </div>

            {/* Test Result */}
            {testResult && (
              <div className={`p-4 rounded-lg mb-4 ${
                testResult.success 
                  ? 'bg-green-900/30 border border-green-700 text-green-200' 
                  : 'bg-red-900/30 border border-red-700 text-red-200'
              }`}>
                <p className="text-sm">{testResult.message}</p>
              </div>
            )}

            {/* Preset Buttons */}
            <div className="space-y-2 mb-6">
              <p className="text-sm font-medium text-gray-400 mb-3">Quick Presets:</p>
              {NETWORK_PRESETS.map((preset) => (
                <button
                  key={preset.name}
                  onClick={() => {
                    setEndpoint(preset.url);
                    setSaved(false);
                    setTestResult(null);
                  }}
                  className={`block w-full text-left px-4 py-3 rounded-lg transition-colors ${
                    endpoint === preset.url
                      ? 'bg-blue-900/30 border-2 border-blue-600'
                      : 'bg-gray-800 border border-gray-700 hover:bg-gray-700'
                  }`}
                >
                  <div className="font-medium">{preset.name}</div>
                  <div className="text-sm text-gray-400 mt-1">{preset.description}</div>
                  <div className="text-xs text-gray-500 mt-1 font-mono">{preset.url}</div>
                </button>
              ))}
            </div>

            {/* Save Button */}
            <button
              onClick={handleSave}
              disabled={saved || !endpoint}
              className="w-full bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 disabled:from-gray-700 disabled:to-gray-700 disabled:cursor-not-allowed text-white py-4 rounded-xl font-medium flex items-center justify-center gap-2 transition-all"
            >
              {saved ? (
                <>
                  <Save className="w-5 h-5" />
                  Saved! Reloading...
                </>
              ) : (
                <>
                  <Save className="w-5 h-5" />
                  Save & Reconnect
                </>
              )}
            </button>
          </div>

          {/* Info Panel */}
          <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-4">
            <h4 className="font-medium text-blue-200 mb-2">ℹ️ Connection Tips</h4>
            <ul className="text-sm text-blue-300 space-y-1">
              <li>• Test connection before saving to verify endpoint works</li>
              <li>• Local testnet: Make sure your node is running</li>
              <li>• Remote testnet: Get endpoint URL from your friend</li>
              <li>• Changing network will reload the app</li>
            </ul>
          </div>

          {/* Warning */}
          <div className="bg-yellow-900/20 border border-yellow-700 rounded-lg p-4">
            <h4 className="font-medium text-yellow-200 mb-2">⚠️ Important</h4>
            <p className="text-sm text-yellow-300">
              Make sure the endpoint is accessible before connecting. Wrong endpoints may cause errors.
            </p>
          </div>
        </div>
      </div>

      {/* Additional Settings (Future) */}
      <div className="mt-6 bg-uat-gray border border-gray-700 rounded-2xl p-6">
        <h3 className="text-lg font-semibold mb-4">App Info</h3>
        <div className="space-y-2 text-sm text-gray-400">
          <div className="flex justify-between">
            <span>Version:</span>
            <span className="text-white">0.1.0</span>
          </div>
          <div className="flex justify-between">
            <span>Current Network:</span>
            <span className="text-white">{endpoint.includes('localhost') ? 'Local' : 'Remote'}</span>
          </div>
          <div className="flex justify-between">
            <span>Chain:</span>
            <span className="text-white">Unauthority (UAT)</span>
          </div>
        </div>
      </div>
    </div>
  );
}
