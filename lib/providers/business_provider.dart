import 'package:flutter/foundation.dart';

import '../models/business_model.dart';
import '../services/business_service.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessProvider(this._businessService);

  final BusinessService _businessService;

  List<BusinessModel> _businesses = [];
  String _selectedCategory = 'Todos';
  bool _isLoading = false;
  String? _error;

  List<BusinessModel> get businesses => _businesses;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBusinesses({String? category}) async {
    if (category != null) {
      _selectedCategory = category;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _businesses = await _businessService.getBusinesses(
        category: _selectedCategory,
      );
    } catch (_) {
      _error = 'No se pudieron cargar las marcas aliadas.';
      _businesses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BusinessModel?> getBusinessById(String id) {
    return _businessService.getBusinessById(id);
  }
}
