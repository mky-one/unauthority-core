import { create } from 'zustand';
import { NodeInfo, ValidatorInfo } from '../utils/api';

interface ValidatorState {
  nodeInfo: NodeInfo | null;
  validators: ValidatorInfo[];
  isConnected: boolean;
  lastUpdate: number;
  ownAddress: string | null;
  
  setNodeInfo: (info: NodeInfo) => void;
  setValidators: (validators: ValidatorInfo[]) => void;
  setConnected: (connected: boolean) => void;
  updateTimestamp: () => void;
  setOwnAddress: (address: string) => void;
}

export const useValidatorStore = create<ValidatorState>((set) => ({
  nodeInfo: null,
  validators: [],
  isConnected: false,
  lastUpdate: 0,
  ownAddress: null,
  
  setNodeInfo: (info) => set({ nodeInfo: info }),
  setValidators: (validators) => set({ validators }),
  setConnected: (connected) => set({ isConnected: connected }),
  updateTimestamp: () => set({ lastUpdate: Date.now() }),
  setOwnAddress: (address) => set({ ownAddress: address }),
}));
