import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/payment_model.dart';
import 'package:running_dart/models/membership_modality.dart';

void main() {
  test('PaymentModel toFirestore includes receiptUrl when provided', () {
    final payment = PaymentModel(
      id: 'pay-1',
      userId: 'user-1',
      modality: MembershipModality.official,
      amount: 5,
      paidAt: DateTime(2026, 3, 15),
      status: PaymentStatus.pending,
      receiptUrl: 'https://example.com/receipt.jpg',
    );

    expect(
      payment.toFirestore()['receiptUrl'],
      'https://example.com/receipt.jpg',
    );
  });
}
