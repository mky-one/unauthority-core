import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/dilithium_service.dart';
import 'services/wallet_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dilithium5 post-quantum crypto (loads native lib if available)
  await DilithiumService.initialize();
  print(DilithiumService.isAvailable
      ? '🔐 Dilithium5 ready (PK: ${DilithiumService.publicKeyBytes}B, SK: ${DilithiumService.secretKeyBytes}B)'
      : '⚠️  Dilithium5 not available — SHA256 fallback active');

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
          create: (_) => ApiService(),
          dispose: (_, api) => api.dispose(),
        ),
        Provider<WalletService>.value(value: walletService),
      ],
      child: MaterialApp(
        title: 'UAT Validator Dashboard',
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
        home: const DashboardScreen(),
      ),
    );
  }
}
