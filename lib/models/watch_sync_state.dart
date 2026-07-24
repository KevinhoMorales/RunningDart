import '../services/qr_service.dart';
import 'user_model.dart';

class WatchSyncState {
  const WatchSyncState({
    required this.isLoggedIn,
    required this.canShowQr,
    this.qrPayload,
    this.displayName,
    required this.updatedAt,
  });

  final bool isLoggedIn;
  final bool canShowQr;
  final String? qrPayload;
  final String? displayName;
  final DateTime updatedAt;

  factory WatchSyncState.fromUser(UserModel? user) {
    final updatedAt = DateTime.now().toUtc();

    if (user == null) {
      return WatchSyncState(
        isLoggedIn: false,
        canShowQr: false,
        updatedAt: updatedAt,
      );
    }

    final canShowQr = user.hasMembershipPrivileges;
    final qrService = QRService();

    return WatchSyncState(
      isLoggedIn: true,
      canShowQr: canShowQr,
      qrPayload: canShowQr ? qrService.generatePayload(user) : null,
      displayName: user.displayName,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLoggedIn': isLoggedIn,
      'canShowQr': canShowQr,
      if (qrPayload != null) 'qrPayload': qrPayload,
      if (displayName != null) 'displayName': displayName,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
