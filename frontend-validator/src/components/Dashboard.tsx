import { useValidatorStore } from '../store/validatorStore';
import { formatCilToLOS } from '../utils/format';
import { Cpu, HardDrive, Users, TrendingUp, Wallet } from 'lucide-react';

export default function Dashboard() {
  const { nodeInfo, validators, isConnected, ownAddress } = useValidatorStore();

  if (!isConnected || !nodeInfo) {
    return (
      <div className="bg-los-gray border border-gray-700 rounded-xl p-8 text-center">
        <p className="text-gray-400">Node offline. Please check your connection.</p>
      </div>
    );
  }

  const totalStake = validators.reduce((sum, v) => sum + v.stake, 0);
  const activeValidators = validators.filter((v) => v.is_active).length;

  const stats = [
    {
      label: 'Total Supply',
      value: `${(nodeInfo.total_supply || 0).toLocaleString()} LOS`,
      icon: HardDrive,
      color: 'text-blue-400',
    },
    {
      label: 'Active Validators',
      value: `${activeValidators} / ${validators.length}`,
      icon: Users,
      color: 'text-green-400',
    },
    {
      label: 'Total Staked',
      value: `${formatCilToLOS(totalStake)} LOS`,
      icon: TrendingUp,
      color: 'text-purple-400',
    },
    {
      label: 'Block Height',
      value: nodeInfo.block_height.toLocaleString(),
      icon: Cpu,
      color: 'text-cyan-400',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <div
              key={stat.label}
              className="bg-gradient-to-br from-los-gray to-slate-900 border border-gray-700 rounded-xl p-6 hover:border-gray-600 transition-colors"
            >
              <div className="flex items-center justify-between mb-4">
                <Icon className={`w-8 h-8 ${stat.color}`} />
              </div>
              <p className="text-2xl font-bold text-white mb-1">{stat.value}</p>
              <p className="text-sm text-gray-400">{stat.label}</p>
            </div>
          );
        })}
      </div>

      {/* Node Info */}
      <div className="bg-los-gray border border-gray-700 rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Node Information</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-xs text-gray-400 mb-1">Chain ID</p>
            <p className="font-mono text-sm text-white">{nodeInfo.chain_id}</p>
          </div>
          <div>
            <p className="text-xs text-gray-400 mb-1">Version</p>
            <p className="font-mono text-sm text-white">{nodeInfo.version}</p>
          </div>
          <div>
            <p className="text-xs text-gray-400 mb-1">Peers</p>
            <p className="font-mono text-sm text-white">{nodeInfo.peer_count} connected</p>
          </div>
          <div>
            <p className="text-xs text-gray-400 mb-1">Network TPS</p>
            <p className="font-mono text-sm text-white">{nodeInfo.network_tps} tx/s</p>
          </div>
        </div>
      </div>

      {/* Own Validator Address */}
      {ownAddress && (
        <div className="bg-gradient-to-br from-los-blue/10 to-los-cyan/10 border border-los-blue/30 rounded-xl p-6">
          <div className="flex items-center space-x-3 mb-3">
            <Wallet className="w-5 h-5 text-los-cyan" />
            <h3 className="text-lg font-semibold text-white">Your Validator Address</h3>
          </div>
          <div className="bg-los-dark/50 rounded-lg p-4">
            <p className="font-mono text-sm text-los-cyan break-all">{ownAddress}</p>
          </div>
          <p className="text-xs text-gray-400 mt-2">This is your validator's unique address on the network</p>
        </div>
      )}

      {/* Recent Activity */}
      <div className="bg-los-gray border border-gray-700 rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Recent Activity</h3>
        <p className="text-gray-400 text-sm">Block validation and consensus data will appear here...</p>
      </div>
    </div>
  );
}
