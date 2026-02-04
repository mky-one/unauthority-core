/**
 * Wallet State Management (Zustand)
 */

import { create } from 'zustand';
import { Wallet } from '../utils/wallet';
import { getBalance } from '../utils/api';

interface WalletState {
  wallet: Wallet | null;
  balance: number;
  isConnected: boolean;
  setWallet: (wallet: Wallet) => void;
  setBalance: (balance: number) => void;
  setConnected: (connected: boolean) => void;
  clearWallet: () => void;
  fetchBalance: (address: string) => Promise<void>;
}

export const useWalletStore = create<WalletState>()((set) => ({
  wallet: null,
  balance: 0,
  isConnected: false,
  setWallet: (wallet) => set({ wallet }),
  setBalance: (balance) => set({ balance }),
  setConnected: (connected) => set({ isConnected: connected }),
  clearWallet: () => set({ wallet: null, balance: 0 }),
  fetchBalance: async (address: string) => {
    try {
      const balanceData = await getBalance(address);
      if (balanceData) {
        set({ balance: balanceData });
      }
    } catch (error) {
      console.error('Failed to fetch balance:', error);
    }
  },
}));
