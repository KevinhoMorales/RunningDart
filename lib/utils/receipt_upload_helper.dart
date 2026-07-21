import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/membership_modality.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import '../widgets/haptic_controls.dart';
import 'membership_helpers.dart';

class ReceiptUploadHelper {
  ReceiptUploadHelper._();

  static Future<XFile?> pickReceipt(
    BuildContext context,
    ImagePicker picker,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HapticListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            HapticListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return null;
    }

    return picker.pickImage(source: source, imageQuality: 85);
  }

  static String contentTypeFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }
    if (name.endsWith('.heic') || name.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  static Future<void> submitReceipt({
    required PaymentService paymentService,
    required String userId,
    required MembershipModality modality,
    required XFile receiptFile,
  }) async {
    final bytes = await receiptFile.readAsBytes();
    final paymentId = DateTime.now().millisecondsSinceEpoch.toString();
    final receiptUrl = await paymentService.uploadReceiptBytes(
      userId: userId,
      paymentId: paymentId,
      bytes: Uint8List.fromList(bytes),
      contentType: contentTypeFor(receiptFile),
    );

    await paymentService.createPayment(
      PaymentModel(
        id: paymentId,
        userId: userId,
        modality: modality,
        amount: MembershipHelpers.amountForModality(modality),
        paidAt: DateTime.now(),
        status: PaymentStatus.pending,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
      ),
    );
  }
}
