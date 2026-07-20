import '../models/visit_model.dart';
import 'visit_service.dart';

class MockVisitService implements VisitServiceBase {
  @override
  Stream<List<VisitModel>> watchVisitsForBusiness(String businessId) {
    return Stream.value(const []);
  }

  @override
  Future<VisitModel> processScan({
    required String rawQrValue,
    required String businessId,
    required String scannedByUserId,
  }) async {
    throw UnimplementedError();
  }
}
