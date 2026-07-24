import '../models/visit_model.dart';
import 'visit_service.dart';

class MockVisitService implements VisitServiceBase {
  @override
  Stream<List<VisitModel>> watchVisitsForBusiness(String businessId) {
    return Stream.value(const []);
  }

  @override
  Future<ScanValidationResult> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ScanValidationResult> processManualCode({
    required String code,
    required String businessId,
    required String scannedByUserId,
  }) async {
    throw UnimplementedError();
  }
}
