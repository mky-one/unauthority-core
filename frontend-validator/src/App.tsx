import { useState, useEffect } from 'react';
import { Activity, Users, Box, Settings, Send, LogOut, RefreshCw } from 'lucide-react';
import { useValidatorStore } from './store/validatorStore';
import { getNodeInfo, getValidators, checkNodeConnection } from './utils/api';
import { isConfigured, clearKeys } from './utils/keyManager';
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
  const [isRefreshing, setIsRefreshing] = useState(false);

  const handleSetupComplete = async () => {
    // Keys are already saved by SetupWizard component via keyManager.storeKeys()
    // Just close the setup wizard and show the dashboard
    setShowSetupWizard(false);
  };

  const handleLogout = () => {
    if (confirm('Are you sure you want to logout? You will need your password to login again.')) {
      clearKeys();
      setShowSetupWizard(true);
    }
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
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
    
    setTimeout(() => setIsRefreshing(false), 500);
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
    return <SetupWizard onComplete={handleSetupComplete} />;
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
              onClick={handleRefresh}
              disabled={isRefreshing}
              className="flex items-center space-x-2 bg-gray-700 hover:bg-gray-600 disabled:opacity-50 text-white font-medium px-3 py-2 rounded-lg transition-colors"
              title="Refresh data"
            >
              <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
            
            <button
              onClick={() => setSendModalOpen(true)}
              disabled={!ownAddress}
              className="flex items-center space-x-2 bg-gradient-to-r from-uat-blue to-uat-cyan hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium px-4 py-2 rounded-lg transition-opacity"
            >
              <Send className="w-4 h-4" />
              <span>Send</span>
            </button>
            
            <button
              onClick={handleLogout}
              className="flex items-center space-x-2 bg-red-600 hover:bg-red-500 text-white font-medium px-3 py-2 rounded-lg transition-colors"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
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
