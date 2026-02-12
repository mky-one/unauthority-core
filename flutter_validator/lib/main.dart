import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'screens/node_control_screen.dart';
import 'services/api_service.dart';
import 'services/network_config.dart';
import 'services/dilithium_service.dart';
import 'services/wallet_service.dart';
import 'services/network_status_service.dart';
import 'services/node_process_service.dart';
import 'services/tor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load bootstrap node addresses from assets/network_config.json
  await NetworkConfig.load();

  // Initialize Dilithium5 post-quantum crypto (loads native lib if available)
  await DilithiumService.initialize();
  debugPrint(
    DilithiumService.isAvailable
        ? '🔐 Dilithium5 ready (PK: ${DilithiumService.publicKeyBytes}B, SK: ${DilithiumService.secretKeyBytes}B)'
        : '⚠️  Dilithium5 not available — SHA256 fallback active',
  );

  // Migrate any plaintext secrets from SharedPreferences → SecureStorage
  final walletService = WalletService();
  await walletService.migrateFromSharedPreferences();

  runApp(MyApp(walletService: walletService));
}

class MyApp extends StatefulWidget {
  final WalletService walletService;

  const MyApp({super.key, required this.walletService});

  /// Call this to force the app to re-check wallet state (e.g., after unregister)
  static void resetToSetup(BuildContext context) {
    context.findAncestorStateOfType<_MyAppState>()?.resetRouter();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Key _routerKey = UniqueKey();

  void resetRouter() {
    setState(() => _routerKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TorService>(
          create: (_) => TorService(),
          dispose: (_, tor) => tor.stop(),
        ),
        Provider<ApiService>(
          create: (ctx) => ApiService(torService: ctx.read<TorService>()),
          dispose: (_, api) => api.dispose(),
        ),
        Provider<WalletService>.value(value: widget.walletService),
        ChangeNotifierProvider<NetworkStatusService>(
          create: (context) => NetworkStatusService(context.read<ApiService>()),
        ),
        ChangeNotifierProvider<NodeProcessService>(
          create: (_) => NodeProcessService(),
        ),
      ],
      child: MaterialApp(
        title: 'LOS Validator Node',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B4CE6),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0A0E1A),
          cardTheme: const CardThemeData(
            color: Color(0xFF1A1F2E),
            elevation: 4,
          ),
        ),
        home: _AppRouter(key: _routerKey),
        routes: {
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
  }
}

/// Routes based on wallet registration state:
/// - No wallet → SetupWizard (import wallet + validate balance >= 1000 LOS)
/// - Wallet registered → NodeControlScreen (dashboard + settings)
class _AppRouter extends StatefulWidget {
  const _AppRouter({super.key});

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _loading = true;
  bool _hasWallet = false;

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final walletService = context.read<WalletService>();
    final wallet = await walletService.getCurrentWallet();
    if (!mounted) return;
    setState(() {
      _hasWallet = wallet != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasWallet) {
      return const NodeControlScreen();
    }
    return SetupWizardScreen(
      onSetupComplete: () {
        setState(() => _hasWallet = true);
      },
    );
  }
}
