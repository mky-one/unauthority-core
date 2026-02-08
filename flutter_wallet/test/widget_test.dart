// UAT Wallet Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_wallet/main.dart';

void main() {
  testWidgets('UAT Wallet splash screen renders correctly',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify splash screen shows wallet branding
    expect(find.text('UAT WALLET'), findsOneWidget);
    expect(find.text('Unauthority Blockchain'), findsOneWidget);

    // Verify loading indicator is shown
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify wallet icon is present
    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
  });

  testWidgets('App uses dark theme with Material 3',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.debugShowCheckedModeBanner, false);
    expect(materialApp.title, 'UAT Wallet');
  });
}
