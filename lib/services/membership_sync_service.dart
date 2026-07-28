import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_environment.dart';
import '../utils/user_messages.dart';

class MembershipSyncException implements Exception {
  MembershipSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Syncs an active RevenueCat Pro entitlement into Firestore membership fields.
///
/// Firestore rules block clients from changing role / membershipStatus, so the
/// trusted path is this callable (which verifies with RevenueCat server-side).
class MembershipSyncService {
  MembershipSyncService({FirebaseFunctions? functions}) : _functions = functions;

  FirebaseFunctions? _functions;

  FirebaseFunctions get _functionsOrDefault =>
      _functions ??= FirebaseFunctions.instance;

  Future<bool> syncProMembershipFromRevenueCat() async {
    try {
      final callable = _functionsOrDefault.httpsCallable(
        'syncProMembershipFromRevenueCat',
      );
      final result = await callable.call({
        'environment': AppEnvironment.current.name,
      });
      final data = result.data;
      if (data is Map) {
        return data['activated'] == true || data['alreadyActive'] == true;
      }
      return false;
    } on FirebaseFunctionsException catch (error) {
      final serverMessage = error.message?.trim();
      if (serverMessage != null && serverMessage.isNotEmpty) {
        throw MembershipSyncException(serverMessage);
      }
      throw MembershipSyncException(UserMessages.functions(error));
    } catch (_) {
      throw MembershipSyncException(
        'No se pudo activar tu membresía Pro. Intenta de nuevo.',
      );
    }
  }
}
