import { useValidatorStore } from '../store/validatorStore';
import { formatCilToLOS, shortenAddress } from '../utils/format';
import { Shield, CheckCircle, XCircle, Star } from 'lucide-react';

export default function ValidatorsList() {
  const { validators, isConnected, ownAddress } = useValidatorStore();

  if (!isConnected) {
    return (
      <div className="bg-los-gray border border-gray-700 rounded-xl p-8 text-center">
        <p className="text-gray-400">Node offline. Cannot fetch validator list.</p>
      </div>
    );
  }

  if (validators.length === 0) {
    return (
      <div className="bg-los-gray border border-gray-700 rounded-xl p-8 text-center">
        <Shield className="w-12 h-12 text-gray-500 mx-auto mb-4" />
        <p className="text-gray-400">No validators found.</p>
      </div>
    );
  }

  return (
    <div className="bg-los-gray border border-gray-700 rounded-xl overflow-hidden">
      <div className="p-6 border-b border-gray-700">
        <h3 className="text-lg font-semibold text-white">Active Validators</h3>
        <p className="text-sm text-gray-400 mt-1">
          {validators.filter((v) => v.is_active).length} of {validators.length} validators online
        </p>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-slate-900">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Address
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Stake (LOS)
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Uptime
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-700">
            {validators.map((validator, index) => {
              const isOwn = ownAddress && validator.address === ownAddress;
              return (
                <tr
                  key={index}
                  className={`hover:bg-slate-900/50 transition-colors ${
                    isOwn ? 'bg-los-blue/10' : ''
                  }`}
                >
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center space-x-2">
                      {validator.is_active ? (
                        <CheckCircle className="w-5 h-5 text-green-400" />
                      ) : (
                        <XCircle className="w-5 h-5 text-red-400" />
                      )}
                      {isOwn && <Star className="w-4 h-4 text-yellow-400 fill-yellow-400" />}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center space-x-2">
                      <code className="text-sm text-white">{shortenAddress(validator.address)}</code>
                      {isOwn && (
                        <span className="text-xs bg-los-cyan/20 text-los-cyan px-2 py-1 rounded">
                          YOU
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm text-white font-medium">
                      {formatCilToLOS(validator.stake)}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm text-gray-300">{(validator.uptime_percentage || 0).toFixed(2)}%</span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
