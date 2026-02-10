import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'screens/node_control_screen.dart';
import 'services/api_service.dart';
import 'services/dilithium_service.dart';
import 'services/wallet_service.dart';
import 'services/network_status_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class MyApp extends StatelessWidget {
  final WalletService walletService;

  const MyApp({super.key, required this.walletService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) {
            const isLocal =
                String.fromEnvironment('UAT_LOCAL', defaultValue: 'false');
            if (isLocal == 'true') {
              debugPrint('🔧 [Main] Using LOCAL mode (localhost:3030)');
              return ApiService(environment: NetworkEnvironment.local);
            }
            return ApiService();
          },
          dispose: (_, api) => api.dispose(),
        ),
        Provider<WalletService>.value(value: walletService),
        ChangeNotifierProvider<NetworkStatusService>(
          create: (context) => NetworkStatusService(context.read<ApiService>()),
        ),
      ],
      child: MaterialApp(
        title: 'UAT Validator Node',
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
        home: const _AppRouter(),
        routes: {
          '/setup': (_) => SetupWizardScreen(onSetupComplete: () {}),
          '/control': (_) => const NodeControlScreen(),
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
  }
}

/// Routes based on wallet registration state:
/// - No wallet → SetupWizard (import wallet + validate balance >= 1000 UAT)
/// - Wallet registered → NodeControlScreen (dashboard + settings)
class _AppRouter extends StatefulWidget {
  const _AppRouter();

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
