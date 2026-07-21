import 'package:cloud_functions/cloud_functions.dart';

import 'auth_service.dart';

class AccountDeletionService {
  AccountDeletionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> deleteMyAccount() async {
    try {
      final callable = _functions.httpsCallable('deleteMyAccount');
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(_mapFunctionsError(e));
    } catch (_) {
      throw AuthException(
        'No se pudo eliminar la cuenta. Intenta de nuevo.',
      );
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException exception) {
    return switch (exception.code) {
      'unauthenticated' => 'Debes iniciar sesión para eliminar tu cuenta.',
      'failed-precondition' =>
        'No se pudo verificar tu cuenta. Intenta de nuevo.',
      'unavailable' =>
        'El servicio no está disponible. Intenta más tarde.',
      _ => exception.message ??
          'No se pudo eliminar la cuenta. Intenta de nuevo.',
    };
  }
}
