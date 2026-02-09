import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/wallet_setup_screen.dart';
import 'services/account_management_service.dart';
import 'services/wallet_service.dart';
import 'services/api_service.dart';
import 'services/dilithium_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Dilithium5 native library (non-blocking, graceful fallback)
  await DilithiumService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WalletService>(create: (_) => WalletService()),
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'UAT Wallet',
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
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final walletService = context.read<WalletService>();

    // One-time migration: SharedPreferences → FlutterSecureStorage
    await walletService.migrateFromSharedPreferences();

    // One-time migration: account seed phrases → SecureStorage
    final accountService = AccountManagementService();
    await accountService.migrateSecretsFromSharedPreferences();

    final wallet = await walletService.getCurrentWallet();

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (wallet == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WalletSetupScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'UAT WALLET',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unauthority Blockchain',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
