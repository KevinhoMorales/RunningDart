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

  QRPayload parsePayload(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      throw QRParseException('El código QR está vacío.');
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        throw QRParseException('Formato de QR inválido.');
      }

      final userId = decoded['userId'] as String?;
      final qrCode = decoded['qrCode'] as String?;

      if (userId == null ||
          userId.isEmpty ||
          qrCode == null ||
          qrCode.isEmpty) {
        throw QRParseException('El QR no contiene datos de membresía válidos.');
      }

      return QRPayload(userId: userId, qrCode: qrCode);
    } on FormatException {
      throw QRParseException('Formato de QR inválido.');
    }
  }
}
