import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/visit_model.dart';
import '../services/visit_service.dart';

class VisitProvider extends ChangeNotifier {
  VisitProvider(this._visitService);

  final VisitServiceBase _visitService;

  StreamSubscription<List<VisitModel>>? _subscription;

  List<VisitModel> _visits = [];
  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
  String? _lastScanMessage;

  List<VisitModel> get visits => _visits;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String? get error => _error;
  String? get lastScanMessage => _lastScanMessage;

  void startListening(String businessId) {
    if (_subscription != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription =
        _visitService.watchVisitsForBusiness(businessId).listen(
      (visits) {
        _visits = visits;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudieron cargar las visitas.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void refresh(String businessId) {
    stopListening();
    startListening(businessId);
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  }) async {
    _isScanning = true;
    _error = null;
    _lastScanMessage = null;
    notifyListeners();

    try {
      final visit = await _visitService.processScan(
        rawQrValue: rawQrValue,
        businessId: businessId,
        scannedByUserId: scannedByUserId,
      );
      _lastScanMessage = 'Visita registrada: ${visit.memberDisplayName}';
      return true;
    } on ScanException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'No se pudo registrar la visita.';
      return false;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _error = null;
    _lastScanMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
