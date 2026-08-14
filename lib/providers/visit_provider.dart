import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/page_result.dart';
import '../models/visit_model.dart';
import '../services/visit_service.dart';

class VisitProvider extends ChangeNotifier {
  VisitProvider(this._visitService);

  final VisitServiceBase _visitService;

  StreamSubscription<PageResult<VisitModel>>? _subscription;
  String? _businessId;

  List<VisitModel> _liveVisits = [];
  List<VisitModel> _olderVisits = [];
  Object? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _generation = 0;

  bool _isLoading = false;
  bool _isScanning = false;
  String? _error;
  ScanValidationResult? _lastValidationResult;

  List<VisitModel> get visits {
    final byId = <String, VisitModel>{};
    for (final visit in _olderVisits) {
      byId[visit.id] = visit;
    }
    for (final visit in _liveVisits) {
      byId[visit.id] = visit;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return merged;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isScanning => _isScanning;
  String? get error => _error;
  ScanValidationResult? get lastValidationResult => _lastValidationResult;

  void startListening(String businessId) {
    if (_subscription != null && _businessId == businessId) {
      return;
    }

    // El provider vive a nivel de app, así que un operador reasignado a otro
    // negocio se quedaría viendo las validaciones del anterior.
    _subscription?.cancel();
    _businessId = businessId;
    _generation++;
    _liveVisits = [];
    _olderVisits = [];
    _nextCursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _visitService.watchVisitsForBusiness(businessId).listen(
      (page) {
        _liveVisits = page.items;
        if (_olderVisits.isEmpty) {
          _nextCursor = page.cursor;
          _hasMore = page.hasMore;
        } else {
          final liveIds = page.items.map((v) => v.id).toSet();
          _olderVisits =
              _olderVisits.where((v) => !liveIds.contains(v.id)).toList();
        }
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'No se pudieron cargar las validaciones.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadMore() async {
    final businessId = _businessId;
    if (businessId == null ||
        !_hasMore ||
        _isLoadingMore ||
        _isLoading ||
        _nextCursor == null) {
      return;
    }

    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _visitService.fetchVisitsForBusinessPage(
        businessId,
        startAfter: _nextCursor,
      );
      if (generation != _generation) {
        return;
      }
      final known = <String>{
        for (final v in _liveVisits) v.id,
        for (final v in _olderVisits) v.id,
      };
      final fresh =
          page.items.where((v) => !known.contains(v.id)).toList();
      _olderVisits = [..._olderVisits, ...fresh];
      _nextCursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      debugPrint('No se pudieron cargar más visitas: $error');
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void refresh(String businessId) {
    stopListening();
    startListening(businessId);
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _businessId = null;
  }

  Future<ScanValidationResult> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  }) async {
    _isScanning = true;
    _error = null;
    _lastValidationResult = null;
    notifyListeners();

    try {
      final result = await _visitService.processScan(
        rawQrValue: rawQrValue,
        businessId: businessId,
        scannedByUserId: scannedByUserId,
      );
      _lastValidationResult = result;
      if (!result.isApproved) {
        _error = result.message;
      }
      return result;
    } on ScanException catch (e) {
      _error = e.message;
      final fallback = ScanValidationResult(
        isApproved: false,
        message: e.message,
      );
      _lastValidationResult = fallback;
      return fallback;
    } catch (_) {
      _error = 'No se pudo registrar la validación.';
      final fallback = ScanValidationResult(
        isApproved: false,
        message: 'No se pudo registrar la validación.',
      );
      _lastValidationResult = fallback;
      return fallback;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<ScanValidationResult> processManualCode({
    required String code,
    required String businessId,
    required String scannedByUserId,
  }) async {
    _isScanning = true;
    _error = null;
    _lastValidationResult = null;
    notifyListeners();

    try {
      final result = await _visitService.processManualCode(
        code: code,
        businessId: businessId,
        scannedByUserId: scannedByUserId,
      );
      _lastValidationResult = result;
      if (!result.isApproved) {
        _error = result.message;
      }
      return result;
    } on ScanException catch (e) {
      _error = e.message;
      final fallback = ScanValidationResult(
        isApproved: false,
        message: e.message,
      );
      _lastValidationResult = fallback;
      return fallback;
    } catch (_) {
      _error = 'No se pudo registrar la validación.';
      final fallback = ScanValidationResult(
        isApproved: false,
        message: 'No se pudo registrar la validación.',
      );
      _lastValidationResult = fallback;
      return fallback;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _error = null;
    _lastValidationResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
