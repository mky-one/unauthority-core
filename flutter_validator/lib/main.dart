import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'screens/node_control_screen.dart';
import 'services/api_service.dart';
import 'services/dilithium_service.dart';
import 'services/wallet_service.dart';
import 'services/network_status_service.dart';
import 'services/node_process_service.dart';

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

  // Load node process configuration
  final nodeService = NodeProcessService();
  await nodeService.loadConfig();

  runApp(MyApp(walletService: walletService, nodeService: nodeService));
}

class MyApp extends StatelessWidget {
  final WalletService walletService;
  final NodeProcessService nodeService;

  const MyApp(
      {super.key, required this.walletService, required this.nodeService});

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
        ChangeNotifierProvider<NodeProcessService>.value(value: nodeService),
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

/// Routes to the appropriate screen based on setup state.
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<NodeProcessService>(
      builder: (context, node, _) {
        if (node.setupComplete) {
          return const NodeControlScreen();
        } else {
          return SetupWizardScreen(
            onSetupComplete: () {
              // Force rebuild when setup completes
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          );
        }
      },
    );
  }
}
