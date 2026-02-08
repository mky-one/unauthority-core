import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/account_profile.dart';

class AccountManagementService {
  static const String _storageKey = 'uat_accounts';
  static const String _activeAccountKey = 'uat_active_account';

  final _uuid = const Uuid();

  /// Load all accounts from storage
  Future<AccountsList> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_storageKey);
    final activeAccountId = prefs.getString(_activeAccountKey);

    if (accountsJson == null) {
      return AccountsList(accounts: [], activeAccountId: null);
    }

    try {
      final Map<String, dynamic> data = json.decode(accountsJson);
      final accounts = (data['accounts'] as List?)
              ?.map((a) => AccountProfile.fromJson(a))
              .toList() ??
          [];

      return AccountsList(
        accounts: accounts,
        activeAccountId: activeAccountId,
      );
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      return AccountsList(accounts: [], activeAccountId: null);
    }
  }

  /// Save accounts to storage
  Future<void> saveAccounts(AccountsList accountsList) async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = json.encode({
      'accounts': accountsList.accounts.map((a) => a.toJson()).toList(),
    });

    await prefs.setString(_storageKey, accountsJson);

    if (accountsList.activeAccountId != null) {
      await prefs.setString(_activeAccountKey, accountsList.activeAccountId!);
    } else {
      await prefs.remove(_activeAccountKey);
    }
  }

  /// Create new account
  Future<AccountProfile> createAccount({
    required String name,
    required String address,
    required String seedPhrase,
    String? publicKey,
  }) async {
    final account = AccountProfile(
      id: _uuid.v4(),
      name: name,
      address: address,
      seedPhrase: seedPhrase,
      publicKey: publicKey,
      createdAt: DateTime.now(),
    );

    final accountsList = await loadAccounts();
    final updatedList = accountsList.addAccount(account);

    // Set as active if it's the first account
    if (updatedList.accounts.length == 1) {
      await saveAccounts(updatedList.setActiveAccount(account.id));
    } else {
      await saveAccounts(updatedList);
    }

    return account;
  }

  /// Import account from seed phrase
  Future<AccountProfile> importAccount({
    required String name,
    required String address,
    required String seedPhrase,
    String? publicKey,
  }) async {
    // Check if account already exists
    final accountsList = await loadAccounts();
    final existing = accountsList.accounts.where((a) => a.address == address);

    if (existing.isNotEmpty) {
      throw Exception('Account with this address already exists');
    }

    return createAccount(
      name: name,
      address: address,
      seedPhrase: seedPhrase,
      publicKey: publicKey,
    );
  }

  /// Add hardware wallet account
  Future<AccountProfile> addHardwareWalletAccount({
    required String name,
    required String address,
    required String publicKey,
    required String hardwareWalletId,
  }) async {
    final account = AccountProfile(
      id: _uuid.v4(),
      name: name,
      address: address,
      publicKey: publicKey,
      createdAt: DateTime.now(),
      isHardwareWallet: true,
      hardwareWalletId: hardwareWalletId,
    );

    final accountsList = await loadAccounts();
    final updatedList = accountsList.addAccount(account);
    await saveAccounts(updatedList);

    return account;
  }

  /// Switch active account
  Future<void> switchAccount(String accountId) async {
    final accountsList = await loadAccounts();

    // Verify account exists
    if (!accountsList.accounts.any((a) => a.id == accountId)) {
      throw Exception('Account not found');
    }

    final updatedList = accountsList.setActiveAccount(accountId);
    await saveAccounts(updatedList);
  }

  /// Rename account
  Future<void> renameAccount(String accountId, String newName) async {
    final accountsList = await loadAccounts();
    final account = accountsList.accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => throw Exception('Account not found'),
    );

    final updatedAccount = account.copyWith(name: newName);
    final updatedList = accountsList.updateAccount(updatedAccount);
    await saveAccounts(updatedList);
  }

  /// Delete account
  Future<void> deleteAccount(String accountId) async {
    final accountsList = await loadAccounts();

    // Don't allow deleting the last account
    if (accountsList.accounts.length <= 1) {
      throw Exception('Cannot delete the last account');
    }

    final updatedList = accountsList.removeAccount(accountId);

    // Set first account as active if we deleted the active one
    if (updatedList.activeAccountId == null &&
        updatedList.accounts.isNotEmpty) {
      await saveAccounts(
          updatedList.setActiveAccount(updatedList.accounts.first.id));
    } else {
      await saveAccounts(updatedList);
    }
  }

  /// Get active account
  Future<AccountProfile?> getActiveAccount() async {
    final accountsList = await loadAccounts();
    return accountsList.activeAccount;
  }

  /// Get all accounts
  Future<List<AccountProfile>> getAllAccounts() async {
    final accountsList = await loadAccounts();
    return accountsList.accounts;
  }

  /// Check if account name already exists
  Future<bool> isNameTaken(String name, {String? excludeId}) async {
    final accountsList = await loadAccounts();
    return accountsList.accounts.any(
      (a) => a.name.toLowerCase() == name.toLowerCase() && a.id != excludeId,
    );
  }

  /// Get account count
  Future<int> getAccountCount() async {
    final accountsList = await loadAccounts();
    return accountsList.accounts.length;
  }
}
