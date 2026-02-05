import { useState, useEffect } from 'react';
import { Wallet, ArrowLeftRight, Flame, History, LogOut, RefreshCw, Settings as SettingsIcon, Droplet } from 'lucide-react';
import { useWalletStore } from './store/walletStore';
import { checkNodeConnection, getBalance, getNodeInfo } from './utils/api';
import WalletSetup from './components/WalletSetup.tsx';
import Dashboard from './components/Dashboard.tsx';
import BurnInterface from './components/BurnInterface.tsx';
import SendInterface from './components/SendInterface.tsx';
import HistoryView from './components/HistoryView.tsx';
import FaucetPanel from './components/FaucetPanel.tsx';
import Settings from './components/Settings.tsx';
import NetworkSwitcher from './components/NetworkSwitcher.tsx';

type Tab = 'dashboard' | 'burn' | 'send' | 'history' | 'faucet' | 'settings';

function App() {
  const { wallet, setConnected, setBalance, clearWallet } = useWalletStore();
  const [activeTab, setActiveTab] = useState<Tab>('dashboard');
  const [nodeOnline, setNodeOnline] = useState(false);
  const [oraclePrices, setOraclePrices] = useState<{ eth: number; btc: number } | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Check node connection with CORS support
  useEffect(() => {
    const checkNode = async () => {
      const online = await checkNodeConnection();
      setNodeOnline(online);
      setConnected(online);

      if (online) {
        const info = await getNodeInfo();
        if (info && info.eth_price_usd && info.btc_price_usd) {
          setOraclePrices({
            eth: info.eth_price_usd,
            btc: info.btc_price_usd,
          });
        }
      }
    };

    checkNode();
    const interval = setInterval(checkNode, 10000);
    return () => clearInterval(interval);
  }, [setConnected]);

  // Fetch balance periodically
  useEffect(() => {
    if (!wallet || !nodeOnline) return;

    const fetchBalance = async () => {
      const balance = await getBalance(wallet.address);
      setBalance(balance);
    };

    fetchBalance();
    const interval = setInterval(fetchBalance, 5000);
    return () => clearInterval(interval);
  }, [wallet, nodeOnline, setBalance]);

  const handleLogout = () => {
    if (confirm('Are you sure you want to logout? Your wallet will be removed from this device.')) {
      localStorage.removeItem('uat_wallet');
      clearWallet();
    }
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    
    const online = await checkNodeConnection();
    setNodeOnline(online);
    setConnected(online);

    if (online) {
      const info = await getNodeInfo();
      if (info && info.eth_price_usd && info.btc_price_usd) {
        setOraclePrices({
          eth: info.eth_price_usd,
          btc: info.btc_price_usd,
        });
      }

      if (wallet) {
        const balance = await getBalance(wallet.address);
        setBalance(balance);
      }
    }
    
    setTimeout(() => setIsRefreshing(false), 500);
  };

  if (!wallet) {
    return <WalletSetup />;
  }

  return (
    <div className="h-screen flex flex-col bg-uat-dark">
      {/* Header */}
      <header className="bg-uat-gray border-b border-gray-700 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-gradient-to-br from-uat-blue to-uat-cyan rounded-lg flex items-center justify-center">
              <Wallet className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold">Unauthority Wallet</h1>
              <p className="text-xs text-gray-400">Burn BTC/ETH to Mint UAT</p>
            </div>
          </div>
          
          <div className="flex items-center space-x-4">
            {/* Network Switcher */}
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
              onClick={handleLogout}
              className="flex items-center space-x-2 bg-red-600 hover:bg-red-500 text-white font-medium px-3 py-2 rounded-lg transition-colors"
              title="Logout"
            >
              <LogOut className="w-4 h-4" />
            </button>
            
            <div className="flex items-center space-x-2">
              <div className={`w-2 h-2 rounded-full ${nodeOnline ? 'bg-green-500' : 'bg-red-500'}`}></div>
              <span className="text-sm text-gray-400">
                {nodeOnline ? 'Node Online' : 'Node Offline'}
              </span>
            </div>
            
            {oraclePrices && (
              <div className="text-xs text-gray-400 bg-uat-dark px-3 py-1 rounded">
                ETH: ${oraclePrices.eth.toLocaleString()} | BTC: ${oraclePrices.btc.toLocaleString()}
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Tab Navigation */}
      <nav className="bg-uat-gray border-b border-gray-700 px-6">
        <div className="flex space-x-1">
          <TabButton
            icon={<Wallet className="w-4 h-4" />}
            label="Dashboard"
            active={activeTab === 'dashboard'}
            onClick={() => setActiveTab('dashboard')}
          />
          <TabButton
            icon={<Flame className="w-4 h-4" />}
            label="Burn to Mint"
            active={activeTab === 'burn'}
            onClick={() => setActiveTab('burn')}
          />
          <TabButton
            icon={<ArrowLeftRight className="w-4 h-4" />}
            label="Send"
            active={activeTab === 'send'}
            onClick={() => setActiveTab('send')}
          />
          <TabButton
            icon={<History className="w-4 h-4" />}
            label="History"
            active={activeTab === 'history'}
            onClick={() => setActiveTab('history')}
          />
          <TabButton
            icon={<Droplet className="w-4 h-4" />}
            label="Faucet"
            active={activeTab === 'faucet'}
            onClick={() => setActiveTab('faucet')}
          />
          <TabButton
            icon={<SettingsIcon className="w-4 h-4" />}
            label="Settings"
            active={activeTab === 'settings'}
            onClick={() => setActiveTab('settings')}
          />
        </div>
      </nav>

      {/* Main Content */}
      <main className="flex-1 overflow-auto">
        {activeTab === 'dashboard' && <Dashboard nodeOnline={nodeOnline} oraclePrices={oraclePrices} />}
        {activeTab === 'burn' && <BurnInterface nodeOnline={nodeOnline} oraclePrices={oraclePrices} />}
        {activeTab === 'send' && <SendInterface nodeOnline={nodeOnline} />}
        {activeTab === 'history' && <HistoryView />}
        {activeTab === 'faucet' && <FaucetPanel />}
        {activeTab === 'settings' && <Settings />}
      </main>
    </div>
  );
}

interface TabButtonProps {
  icon: React.ReactNode;
  label: string;
  active: boolean;
  onClick: () => void;
}

function TabButton({ icon, label, active, onClick }: TabButtonProps) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center space-x-2 px-4 py-3 border-b-2 transition-colors ${
        active
          ? 'border-uat-blue text-white bg-uat-dark'
          : 'border-transparent text-gray-400 hover:text-white hover:bg-uat-dark'
      }`}
    >
      {icon}
      <span className="text-sm font-medium">{label}</span>
    </button>
  );
}

export default App;
