import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/config/firebase_paths.dart';

void main() {
  test('builds environment-scoped Firestore user document paths', () {
    expect(
      FirebasePaths.firestoreUserDocumentPath('abc123'),
      'environments/prod/users/abc123',
    );
  });

  test('builds environment-scoped storage paths', () {
    expect(
      FirebasePaths.storagePath('users/abc123/profile.jpg'),
      'environments/prod/users/abc123/profile.jpg',
    );

    expect(
      FirebasePaths.storagePath('payments/user-1/pay-1/receipt.jpg'),
      'environments/prod/payments/user-1/pay-1/receipt.jpg',
    );
  });

  test('normalizes leading slashes in storage paths', () {
    expect(
      FirebasePaths.storagePath('/businesses/biz-1/cover.jpg'),
      'environments/prod/businesses/biz-1/cover.jpg',
    );
  });
}
