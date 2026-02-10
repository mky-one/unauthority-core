import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/node_process_service.dart';

/// Multi-step setup wizard for first-time validator node configuration.
///
/// Steps:
/// 1. Locate uat-node binary
/// 2. Configure ports & bootstrap nodes
/// 3. Start the node
/// 4. Fund the node (faucet) to reach validator stake
class SetupWizardScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const SetupWizardScreen({super.key, required this.onSetupComplete});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  bool _isBusy = false;
  String? _statusMsg;

  // Step 1: Binary
  final _binaryController = TextEditingController();
  bool _binaryValid = false;

  // Step 2: Config
  final _nodeIdController = TextEditingController(text: 'my-validator');
  final _restPortController = TextEditingController(text: '3535');
  final _p2pPortController = TextEditingController(text: '4005');
  final _bootstrapController = TextEditingController();

  // Step 4: Fund
  int _nodeBalance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromConfig());
  }

  void _initFromConfig() {
    final node = context.read<NodeProcessService>();
    if (node.binaryPath != null) {
      _binaryController.text = node.binaryPath!;
      _binaryValid = true;
    }
    _nodeIdController.text = node.nodeId;
    _restPortController.text = node.restPort.toString();
    _p2pPortController.text = node.p2pPort.toString();
    _bootstrapController.text = node.bootstrapNodes;
    setState(() {});
  }

  @override
  void dispose() {
    _binaryController.dispose();
    _nodeIdController.dispose();
    _restPortController.dispose();
    _p2pPortController.dispose();
    _bootstrapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 48, color: Colors.purpleAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'UAT Validator Setup',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${_currentStep + 1} of 4',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: List.generate(4, (i) {
                  final isActive = i <= _currentStep;
                  final isCurrent = i == _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color:
                            isActive ? Colors.purpleAccent : Colors.grey[800],
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                    color: Colors.purpleAccent.withOpacity(0.5),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStep(),
                ),
              ),
            ),

            // Status message
            if (_statusMsg != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  _statusMsg!,
                  style: TextStyle(
                    color: _statusMsg!.startsWith('✅')
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed:
                          _isBusy ? null : () => setState(() => _currentStep--),
                      child: const Text('BACK',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  const Spacer(),
                  _buildNextButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Binary();
      case 1:
        return _buildStep2Config();
      case 2:
        return _buildStep3Start();
      case 3:
        return _buildStep4Fund();
      default:
        return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // STEP 1: Locate Binary
  // ══════════════════════════════════════════════════════════════════

  Widget _buildStep1Binary() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Locate Node Binary'),
        const SizedBox(height: 8),
        Text(
          'The uat-node binary is required to run your validator. '
          'We\'ll try to find it automatically.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Binary path input
        TextField(
          controller: _binaryController,
          style: const TextStyle(
              color: Colors.white, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Binary Path',
            labelStyle: TextStyle(color: Colors.grey[500]),
            hintText: '/path/to/uat-node',
            hintStyle: TextStyle(color: Colors.grey[700]),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: _binaryValid ? Colors.greenAccent : Colors.grey[700]!),
            ),
            suffixIcon: _binaryValid
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : null,
          ),
          onChanged: (v) => _validateBinaryPath(v),
        ),

        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.search,
                label: 'Auto-Detect',
                onPressed: _autoDetectBinary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                icon: Icons.build,
                label: 'Build from Source',
                onPressed: _buildFromSource,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Info box
        _infoBox(
          'The binary is usually at:\n'
          '  target/release/uat-node (from project root)\n'
          '  ~/.uat/bin/uat-node\n\n'
          'Or press "Build from Source" if you have Rust installed.',
        ),
      ],
    );
  }

  Future<void> _autoDetectBinary() async {
    setState(() {
      _isBusy = true;
      _statusMsg = 'Searching for uat-node binary...';
    });

    final node = context.read<NodeProcessService>();
    await node.loadConfig();

    if (node.binaryPath != null &&
        await node.validateBinary(node.binaryPath!)) {
      _binaryController.text = node.binaryPath!;
      _binaryValid = true;
      _statusMsg = '✅ Found binary at: ${node.binaryPath}';
    } else {
      _statusMsg =
          'Binary not found. Enter path manually or Build from Source.';
    }

    setState(() => _isBusy = false);
  }

  Future<void> _buildFromSource() async {
    setState(() {
      _isBusy = true;
      _statusMsg = 'Building uat-node... This may take 2-5 minutes.';
    });

    final node = context.read<NodeProcessService>();

    // Try to find project root
    final candidates = [
      '${Platform.environment['HOME']}/Documents/unauthority-core',
      '.',
      '..',
      '../..',
    ];

    String? projectRoot;
    for (final c in candidates) {
      if (await File('$c/Cargo.toml').exists()) {
        projectRoot = c;
        break;
      }
    }

    if (projectRoot == null) {
      setState(() {
        _isBusy = false;
        _statusMsg = 'Could not find Cargo.toml. Clone the repo first.';
      });
      return;
    }

    final success = await node.buildBinary(projectRoot: projectRoot);
    if (success) {
      _binaryController.text = node.binaryPath!;
      _binaryValid = true;
      _statusMsg = '✅ Build successful!';
    } else {
      _statusMsg = node.lastError ?? 'Build failed';
    }

    setState(() => _isBusy = false);
  }

  Future<void> _validateBinaryPath(String path) async {
    if (path.isEmpty) {
      setState(() => _binaryValid = false);
      return;
    }

    final node = context.read<NodeProcessService>();
    final valid = await node.validateBinary(path);
    setState(() => _binaryValid = valid);
    if (valid) {
      node.setBinaryPath(path);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // STEP 2: Configure
  // ══════════════════════════════════════════════════════════════════

  Widget _buildStep2Config() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Node Configuration'),
        const SizedBox(height: 8),
        Text(
          'Configure your validator node. Default values work for most setups.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 24),
        _configField('Node ID', _nodeIdController, 'my-validator'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child:
                    _configField('REST API Port', _restPortController, '3535')),
            const SizedBox(width: 16),
            Expanded(
                child: _configField('P2P Port', _p2pPortController, '4005')),
          ],
        ),
        const SizedBox(height: 16),
        _configField('Bootstrap Nodes', _bootstrapController,
            '/ip4/127.0.0.1/tcp/4001,/ip4/127.0.0.1/tcp/4002',
            maxLines: 3),
        const SizedBox(height: 24),
        _infoBox(
          'REST API Port: The HTTP port for your node\'s API.\n'
          'P2P Port: The port for peer-to-peer communication.\n'
          'Bootstrap Nodes: Existing nodes to connect to.\n\n'
          'For local testnet: use defaults.\n'
          'For remote testnet: use .onion bootstrap addresses.',
        ),
      ],
    );
  }

  Widget _configField(
      String label, TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          color: Colors.white, fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STEP 3: Start Node
  // ══════════════════════════════════════════════════════════════════

  Widget _buildStep3Start() {
    return Consumer<NodeProcessService>(
      builder: (context, node, _) {
        final isRunning = node.status == NodeStatus.running;
        final isStarting = node.status == NodeStatus.starting;

        return Column(
          key: const ValueKey('step3'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Launch Your Node'),
            const SizedBox(height: 8),
            Text(
              isRunning
                  ? 'Your node is running and healthy!'
                  : isStarting
                      ? 'Starting your node... Please wait.'
                      : 'Press the button below to start your validator node.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Big start button
            Center(
              child: GestureDetector(
                onTap: isRunning || _isBusy ? null : _startNode,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning
                        ? Colors.green.withOpacity(0.2)
                        : isStarting
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.purpleAccent.withOpacity(0.15),
                    border: Border.all(
                      color: isRunning
                          ? Colors.greenAccent
                          : isStarting
                              ? Colors.orangeAccent
                              : Colors.purpleAccent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isRunning
                                ? Colors.greenAccent
                                : isStarting
                                    ? Colors.orangeAccent
                                    : Colors.purpleAccent)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isStarting)
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                              color: Colors.orangeAccent, strokeWidth: 3),
                        )
                      else
                        Icon(
                          isRunning
                              ? Icons.check_circle
                              : Icons.power_settings_new,
                          size: 48,
                          color: isRunning
                              ? Colors.greenAccent
                              : Colors.purpleAccent,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        isRunning
                            ? 'RUNNING'
                            : isStarting
                                ? 'STARTING'
                                : 'START',
                        style: TextStyle(
                          color: isRunning
                              ? Colors.greenAccent
                              : isStarting
                                  ? Colors.orangeAccent
                                  : Colors.purpleAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Node info
            if (node.nodeAddress != null) _nodeInfoCard(node),

            // Log preview
            if (node.logs.isNotEmpty) _logPreview(node),
          ],
        );
      },
    );
  }

  Widget _nodeInfoCard(NodeProcessService node) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
              const SizedBox(width: 8),
              const Text('Node Info',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.grey),
          _infoRow('Address', node.nodeAddress ?? 'Loading...'),
          _infoRow('PID', node.nodePid?.toString() ?? '—'),
          _infoRow('REST', 'http://127.0.0.1:${node.restPort}'),
          _infoRow('P2P', 'Port ${node.p2pPort}'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace', fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logPreview(NodeProcessService node) {
    final recentLogs = node.logs.length > 8
        ? node.logs.sublist(node.logs.length - 8)
        : node.logs;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      height: 120,
      child: ListView(
        reverse: true,
        children: recentLogs.reversed.map((line) {
          return Text(
            line,
            style: TextStyle(
              color: line.contains('✅')
                  ? Colors.greenAccent
                  : line.contains('❌') || line.contains('⚠')
                      ? Colors.orangeAccent
                      : Colors.grey[400],
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _startNode() async {
    final node = context.read<NodeProcessService>();

    // Apply config
    node.setBinaryPath(_binaryController.text);
    node.setNodeId(_nodeIdController.text);
    node.setRestPort(int.tryParse(_restPortController.text) ?? 3535);
    node.setP2pPort(int.tryParse(_p2pPortController.text) ?? 4005);
    node.setBootstrapNodes(_bootstrapController.text);
    await node.saveConfig();

    setState(() {
      _isBusy = true;
      _statusMsg = 'Starting node...';
    });

    final success = await node.startNode();
    setState(() {
      _isBusy = false;
      _statusMsg = success
          ? 'Node started! Waiting for it to be healthy...'
          : node.lastError;
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // STEP 4: Fund Node
  // ══════════════════════════════════════════════════════════════════

  Widget _buildStep4Fund() {
    return Consumer<NodeProcessService>(
      builder: (context, node, _) {
        final hasEnoughStake = _nodeBalance >= 1000;

        return Column(
          key: const ValueKey('step4'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Fund Your Validator'),
            const SizedBox(height: 8),
            Text(
              hasEnoughStake
                  ? 'Your node has enough stake to be a validator!'
                  : 'Your node needs at least 1,000 UAT to become a validator. '
                      'Request free testnet tokens below.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Balance display
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasEnoughStake
                        ? Colors.greenAccent
                        : Colors.purpleAccent.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Node Balance',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatNumber(_nodeBalance)} UAT',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color:
                            hasEnoughStake ? Colors.greenAccent : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasEnoughStake
                          ? '✅ Validator stake met!'
                          : 'Minimum: 1,000 UAT',
                      style: TextStyle(
                        color: hasEnoughStake
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Faucet button
            if (!hasEnoughStake)
              Center(
                child: SizedBox(
                  width: 280,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _requestFaucet,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.water_drop),
                    label: Text(_isBusy
                        ? 'REQUESTING...'
                        : 'REQUEST FAUCET (5,000 UAT)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            // Refresh balance button
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _refreshBalance,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Balance'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
              ),
            ),

            if (node.nodeAddress != null) ...[
              const SizedBox(height: 24),
              _infoBox(
                'Node Address:\n${node.nodeAddress}\n\n'
                'This address is your validator identity.\n'
                'Minimum stake: 1,000 UAT (faucet gives 5,000).',
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _requestFaucet() async {
    setState(() {
      _isBusy = true;
      _statusMsg = 'Requesting faucet tokens...';
    });

    final node = context.read<NodeProcessService>();
    final result = await node.requestFaucet();

    if (result.containsKey('error')) {
      _statusMsg = 'Faucet error: ${result['error']}';
    } else if (result['status'] == 'success') {
      _statusMsg = '✅ Received ${result['amount'] ?? 5000} UAT!';
      await Future.delayed(const Duration(seconds: 2));
      await _refreshBalance();
    } else {
      _statusMsg =
          'Faucet: ${result['error'] ?? result['msg'] ?? 'Unknown response'}';
    }

    setState(() => _isBusy = false);
  }

  Future<void> _refreshBalance() async {
    final node = context.read<NodeProcessService>();
    final balance = await node.getNodeBalance();
    setState(() => _nodeBalance = balance);
  }

  // ══════════════════════════════════════════════════════════════════
  // NAVIGATION BUTTONS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildNextButton() {
    final node = context.watch<NodeProcessService>();

    switch (_currentStep) {
      case 0: // Binary
        return ElevatedButton(
          onPressed: _binaryValid ? () => setState(() => _currentStep++) : null,
          style: _primaryButtonStyle(),
          child: const Text('NEXT'),
        );

      case 1: // Config
        return ElevatedButton(
          onPressed: () => setState(() => _currentStep++),
          style: _primaryButtonStyle(),
          child: const Text('NEXT'),
        );

      case 2: // Start
        return ElevatedButton(
          onPressed: node.status == NodeStatus.running
              ? () {
                  _refreshBalance();
                  setState(() => _currentStep++);
                }
              : null,
          style: _primaryButtonStyle(),
          child: const Text('NEXT'),
        );

      case 3: // Fund
        final hasStake = _nodeBalance >= 1000;
        return ElevatedButton(
          onPressed: hasStake ? _finishSetup : null,
          style: _primaryButtonStyle(),
          child: Text(hasStake ? 'FINISH SETUP' : 'NEED 1,000 UAT'),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _finishSetup() async {
    final node = context.read<NodeProcessService>();
    await node.saveConfig();
    await node.markSetupComplete();
    widget.onSetupComplete();
  }

  // ══════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ══════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.grey[400], fontSize: 12, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isBusy ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.purpleAccent,
        side: const BorderSide(color: Colors.purpleAccent),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.purpleAccent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
