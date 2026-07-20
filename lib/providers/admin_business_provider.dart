import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/business_model.dart';
import '../services/business_photo_service.dart';
import '../services/business_service.dart';

class AdminBusinessProvider extends ChangeNotifier {
  AdminBusinessProvider(
    this._businessService, {
    BusinessPhotoService? photoService,
  }) : _photoService = photoService;

  final BusinessService _businessService;
  BusinessPhotoService? _photoService;

  StreamSubscription<List<BusinessModel>>? _subscription;

  List<BusinessModel> _businesses = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<BusinessModel> get businesses => _businesses;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  void startListening() {
    if (_subscription != null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _businessService.watchAllBusinesses().listen(
      (businesses) {
        _businesses = businesses;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudieron cargar los negocios.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> refresh() async {
    stopListening();
    final completer = Completer<void>();

    _isLoading = _businesses.isEmpty;
    _error = null;
    notifyListeners();

    _subscription = _businessService.watchAllBusinesses().listen(
      (businesses) {
        _businesses = businesses;
        _isLoading = false;
        _error = null;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudieron cargar los negocios.';
        _isLoading = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        notifyListeners();
      },
    );

    return completer.future;
  }

  Future<String?> createBusiness({
    required BusinessModel business,
    bool uploadPhoto = false,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final businessId = await _businessService.createBusiness(business);

      if (uploadPhoto && business.imageUrl != null) {
        // Photo was picked locally as file path is handled by form screen
      }

      return businessId;
    } catch (_) {
      _error = 'No se pudo crear el negocio.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateBusiness(BusinessModel business) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _businessService.updateBusiness(business);
      return true;
    } catch (_) {
      _error = 'No se pudo actualizar el negocio.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBusiness(String id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _businessService.deleteBusiness(id);
      return true;
    } catch (_) {
      _error = 'No se pudo eliminar el negocio.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadPhoto(String businessId) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final photoService = _photoService ??= BusinessPhotoService();
      return await photoService.pickAndUploadBusinessPhoto(businessId);
    } on BusinessPhotoException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'No se pudo subir la foto.';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
