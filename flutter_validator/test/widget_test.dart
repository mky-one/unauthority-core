// flutter_validator widget smoke test
//
// Verifies the Validator Dashboard app can mount and render
// its primary UI elements without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_validator/main.dart';
import 'package:flutter_validator/services/wallet_service.dart';

void main() {
  testWidgets('Dashboard renders app bar title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(walletService: WalletService()));

    // The app should render the dashboard app bar title
    expect(find.text('UAT Validator Dashboard'), findsOneWidget);
  });

  testWidgets('Dashboard shows loading indicator initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(walletService: WalletService()));

    // Initially shows CircularProgressIndicator while loading data
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
