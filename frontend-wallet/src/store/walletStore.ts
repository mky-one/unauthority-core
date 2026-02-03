/**
 * Wallet State Management (Zustand)
 */

import { create } from 'zustand';
import { Wallet } from '../utils/wallet';

interface WalletState {
  wallet: Wallet | null;
  balance: number;
  isConnected: boolean;
  setWallet: (wallet: Wallet) => void;
  setBalance: (balance: number) => void;
  setConnected: (connected: boolean) => void;
  clearWallet: () => void;
}

export const useWalletStore = create<WalletState>()((set) => ({
  wallet: null,
  balance: 0,
  isConnected: false,
  setWallet: (wallet) => set({ wallet }),
  setBalance: (balance) => set({ balance }),
  setConnected: (connected) => set({ isConnected: connected }),
  clearWallet: () => set({ wallet: null, balance: 0 }),
}));
