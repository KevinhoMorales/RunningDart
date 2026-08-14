import '../models/page_result.dart';
import '../models/visit_model.dart';
import 'visit_service.dart';

class MockVisitService implements VisitServiceBase {
  @override
  Stream<PageResult<VisitModel>> watchVisitsForBusiness(
    String businessId, {
    int limit = VisitServiceBase.visitsPageSize,
  }) {
    return Stream.value(const PageResult(items: [], hasMore: false));
  }

  @override
  Future<PageResult<VisitModel>> fetchVisitsForBusinessPage(
    String businessId, {
    Object? startAfter,
    int limit = VisitServiceBase.visitsPageSize,
  }) async {
    return const PageResult(items: [], hasMore: false);
  }

  @override
  Stream<PageResult<VisitModel>> watchAllVisits({
    int limit = VisitServiceBase.visitsPageSize,
  }) {
    return Stream.value(const PageResult(items: [], hasMore: false));
  }

  @override
  Future<PageResult<VisitModel>> fetchAllVisitsPage({
    Object? startAfter,
    int limit = VisitServiceBase.visitsPageSize,
  }) async {
    return const PageResult(items: [], hasMore: false);
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
