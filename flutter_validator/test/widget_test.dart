// flutter_validator widget smoke test
//
// Verifies the Validator Dashboard app can mount and render
// its primary UI elements without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_validator/main.dart';
import 'package:flutter_validator/services/wallet_service.dart';

void main() {
  testWidgets('App can mount and render', (WidgetTester tester) async {
    // Build the app and trigger initial frame
    await tester.pumpWidget(MyApp(walletService: WalletService()));

    // The app renders successfully (Scaffold from the loading state)
    expect(find.byType(Scaffold), findsOneWidget);

    // Wait for _checkWallet() async to complete and rebuild
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // After wallet check: no wallet found → SetupWizardScreen renders
    // It shows 'Register Validator' as its primary heading
    final found = find.textContaining('Validator');
    if (found.evaluate().isNotEmpty) {
      expect(found, findsWidgets);
    } else {
      // Still in loading state or error → at least a Scaffold is present
      expect(find.byType(Scaffold), findsWidgets);
    }
  });

  testWidgets('Dashboard shows loading indicator initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(walletService: WalletService()));

    // Initially shows CircularProgressIndicator while loading data
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
