enum HardwareWalletType {
  ledgerNanoS,
  ledgerNanoX,
  trezorOne,
  trezorT,
}

enum HardwareWalletStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class HardwareWallet {
  final String id;
  final HardwareWalletType type;
  final HardwareWalletStatus status;
  final String? address;
  final String? publicKey;
  final String? errorMessage;
  final DateTime? connectedAt;

  HardwareWallet({
    required this.id,
    required this.type,
    required this.status,
    this.address,
    this.publicKey,
    this.errorMessage,
    this.connectedAt,
  });

  HardwareWallet copyWith({
    String? id,
    HardwareWalletType? type,
    HardwareWalletStatus? status,
    String? address,
    String? publicKey,
    String? errorMessage,
    DateTime? connectedAt,
  }) {
    return HardwareWallet(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      address: address ?? this.address,
      publicKey: publicKey ?? this.publicKey,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  String get typeName {
    switch (type) {
      case HardwareWalletType.ledgerNanoS:
        return 'Ledger Nano S';
      case HardwareWalletType.ledgerNanoX:
        return 'Ledger Nano X';
      case HardwareWalletType.trezorOne:
        return 'Trezor One';
      case HardwareWalletType.trezorT:
        return 'Trezor Model T';
    }
  }

  String get statusText {
    switch (status) {
      case HardwareWalletStatus.disconnected:
        return 'Disconnected';
      case HardwareWalletStatus.connecting:
        return 'Connecting...';
      case HardwareWalletStatus.connected:
        return 'Connected';
      case HardwareWalletStatus.error:
        return 'Error';
    }
  }

  bool get isConnected => status == HardwareWalletStatus.connected;
}

class HardwareWalletSignature {
  final String signature;
  final String publicKey;
  final DateTime signedAt;

  HardwareWalletSignature({
    required this.signature,
    required this.publicKey,
    required this.signedAt,
  });
}
