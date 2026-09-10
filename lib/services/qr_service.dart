import 'dart:convert';

import '../models/user_model.dart';

class QRPayload {
  const QRPayload({
    required this.userId,
    required this.qrCode,
  });

  final String userId;
  final String qrCode;
}

/// Payload del QR de check-in de una actividad (no confundir con visitas).
class ActivityCheckInQrPayload {
  const ActivityCheckInQrPayload({
    required this.activityId,
    required this.token,
  });

  final String activityId;
  final String token;

  static const String typeValue = 'activity_checkin';
}

class QRParseException implements Exception {
  QRParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QRService {
  String generatePayload(UserModel user) {
    return jsonEncode({
      'userId': user.id,
      'qrCode': user.qrCode,
    });
  }

  String generateActivityCheckInPayload({
    required String activityId,
    required String token,
  }) {
    return jsonEncode({
      'type': ActivityCheckInQrPayload.typeValue,
      'activityId': activityId,
      'token': token,
    });
  }

  QRPayload parsePayload(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      throw QRParseException('El código QR está vacío.');
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw QRParseException('Formato de QR inválido.');
      }
      final map = Map<String, dynamic>.from(decoded);

      if (map['type'] == ActivityCheckInQrPayload.typeValue) {
        throw QRParseException(
          'Este QR es de check-in de actividad, no de membresía.',
        );
      }

      final userId = map['userId'] as String?;
      final qrCode = map['qrCode'] as String?;

      if (userId == null ||
          userId.isEmpty ||
          qrCode == null ||
          qrCode.isEmpty) {
        throw QRParseException('El QR no contiene datos de membresía válidos.');
      }

      return QRPayload(userId: userId, qrCode: qrCode);
    } on QRParseException {
      rethrow;
    } on FormatException {
      throw QRParseException('Formato de QR inválido.');
    }
  }

  ActivityCheckInQrPayload parseActivityCheckInPayload(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      throw QRParseException('El código QR está vacío.');
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw QRParseException('Formato de QR inválido.');
      }
      final map = Map<String, dynamic>.from(decoded);

      if (map['type'] != ActivityCheckInQrPayload.typeValue) {
        throw QRParseException(
          'Este QR no es de check-in de actividad SAINTS.',
        );
      }

      final activityId = map['activityId'] as String?;
      final token = map['token'] as String?;

      if (activityId == null ||
          activityId.isEmpty ||
          token == null ||
          token.isEmpty) {
        throw QRParseException('El QR de check-in está incompleto.');
      }

      return ActivityCheckInQrPayload(
        activityId: activityId,
        token: token,
      );
    } on QRParseException {
      rethrow;
    } on FormatException {
      throw QRParseException('Formato de QR inválido.');
    }
  }
}
