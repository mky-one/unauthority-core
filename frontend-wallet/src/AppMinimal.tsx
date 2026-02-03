import { useEffect, useState } from 'react';
import { useWalletStore } from './store/walletStore';
import WalletSetup from './components/WalletSetup.tsx';
import Dashboard from './components/Dashboard.tsx';
import { checkNodeConnection, getNodeInfo } from './utils/api';

export default function App() {
  const { wallet } = useWalletStore();
  const [nodeOnline, setNodeOnline] = useState(false);
  const [oraclePrices, setOraclePrices] = useState<any>(null);

  // Check node connection every 5 seconds
  useEffect(() => {
    const checkNode = async () => {
      const online = await checkNodeConnection();
      setNodeOnline(online);
      
      if (online) {
        const info = await getNodeInfo();
        if (info) {
          setOraclePrices({
            eth: info.eth_price_usd,
            btc: info.btc_price_usd,
          });
        }
      }
    };

    checkNode(); // Initial check
    const interval = setInterval(checkNode, 5000); // Every 5 seconds
    return () => clearInterval(interval);
  }, []);
  
  if (!wallet) {
    return <WalletSetup />;
  }
  
  return <Dashboard nodeOnline={nodeOnline} oraclePrices={oraclePrices} />;
}
