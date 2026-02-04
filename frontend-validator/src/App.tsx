import { useState, useEffect } from 'react';
import { Activity, Users, Box, Settings, Send } from 'lucide-react';
import { useValidatorStore } from './store/validatorStore';
import { getNodeInfo, getValidators, checkNodeConnection } from './utils/api';
import { isConfigured } from './utils/keyManager';
import Dashboard from './components/Dashboard';
import ValidatorsList from './components/ValidatorsList';
import BlocksView from './components/BlocksView';
import SettingsPanel from './components/SettingsPanel';
import SendModal from './components/SendModal';
import SetupWizard from './components/SetupWizard';
import NetworkSwitcher from './components/NetworkSwitcher';

type Tab = 'dashboard' | 'validators' | 'blocks' | 'settings';

function App() {
  const { setNodeInfo, setValidators, setConnected, isConnected, updateTimestamp, ownAddress } = useValidatorStore();
  const [activeTab, setActiveTab] = useState<Tab>('dashboard');
  const [sendModalOpen, setSendModalOpen] = useState(false);
  const [showSetupWizard, setShowSetupWizard] = useState(!isConfigured());
  const [isNodeStarting, setIsNodeStarting] = useState(false);

  const handleSetupComplete = async (keys: { privateKey: string; publicKey: string }) => {
    setIsNodeStarting(true);
    
    try {
      // Start validator node with provided keys
      const response = await fetch('http://localhost:3030/validator/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          public_key: keys.publicKey,
          private_key: keys.privateKey,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to start validator node');
      }

      // Wait for node to initialize
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      setShowSetupWizard(false);
      setIsNodeStarting(false);
    } catch (error) {
      console.error('Failed to start node:', error);
      alert('Failed to start validator node. Please try again.');
      setIsNodeStarting(false);
    }
  };

  useEffect(() => {
    // Show setup wizard if not configured
    if (!isConfigured()) {
      setShowSetupWizard(true);
      return;
    }

    const checkConnection = async () => {
      const online = await checkNodeConnection();
      setConnected(online);

      if (online) {
        const info = await getNodeInfo();
        if (info) {
          setNodeInfo(info);
          updateTimestamp();
        }

        const validators = await getValidators();
        setValidators(validators);
      }
    };

    checkConnection();
    const interval = setInterval(checkConnection, 10000);
    return () => clearInterval(interval);
  }, [setNodeInfo, setValidators, setConnected, updateTimestamp]);

  if (showSetupWizard) {
    return (
      <>
        <SetupWizard onComplete={handleSetupComplete} />
        {isNodeStarting && (
          <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
            <div className="bg-gray-800 rounded-lg p-8 max-w-md">
              <div className="animate-spin rounded-full h-16 w-16 border-t-2 border-blue-500 mx-auto mb-4"></div>
              <p className="text-white text-center text-lg font-semibold">Starting Validator Node...</p>
              <p className="text-gray-400 text-center text-sm mt-2">
                This may take a few seconds. Connecting to network...
              </p>
            </div>
          </div>
        )}
      </>
    );
  }

  const tabs = [
    { id: 'dashboard' as Tab, label: 'Dashboard', icon: Activity },
    { id: 'validators' as Tab, label: 'Validators', icon: Users },
    { id: 'blocks' as Tab, label: 'Blocks', icon: Box },
    { id: 'settings' as Tab, label: 'Settings', icon: Settings },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-uat-dark via-slate-900 to-uat-gray">
      {/* Header */}
      <header className="bg-uat-gray/50 backdrop-blur border-b border-gray-700">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-gradient-to-br from-uat-blue to-uat-cyan rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-lg">U</span>
            </div>
            <div>
              <h1 className="text-xl font-bold text-white">Unauthority Validator</h1>
              <p className="text-xs text-gray-400">Network Monitoring & Management</p>
            </div>
          </div>

          <div className="flex items-center space-x-4">
            <NetworkSwitcher />
            
            <button
              onClick={() => setSendModalOpen(true)}
              disabled={!ownAddress}
              className="flex items-center space-x-2 bg-gradient-to-r from-uat-blue to-uat-cyan hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium px-4 py-2 rounded-lg transition-opacity"
            >
              <Send className="w-4 h-4" />
              <span>Send</span>
            </button>
            
            <div className="flex items-center space-x-2">
              <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-500' : 'bg-red-500'}`} />
              <span className="text-sm text-gray-300">
                {isConnected ? 'Connected' : 'Offline'}
              </span>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <div className="max-w-7xl mx-auto px-6 pt-6">
        <div className="flex space-x-2 border-b border-gray-700">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center space-x-2 px-4 py-3 transition-colors ${
                  activeTab === tab.id
                    ? 'border-b-2 border-uat-blue text-uat-blue'
                    : 'text-gray-400 hover:text-gray-200'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span className="font-medium">{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Content */}
      <main className="max-w-7xl mx-auto px-6 py-8">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'validators' && <ValidatorsList />}
        {activeTab === 'blocks' && <BlocksView />}
        {activeTab === 'settings' && <SettingsPanel />}
      </main>

      {/* Send Modal */}
      <SendModal
        isOpen={sendModalOpen}
        onClose={() => setSendModalOpen(false)}
        fromAddress={ownAddress}
      />
    </div>
  );
}

export default App;
