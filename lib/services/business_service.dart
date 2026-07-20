import '../models/business_model.dart';

abstract class BusinessService {
  Future<List<BusinessModel>> getBusinesses({String? category});
  Future<BusinessModel?> getBusinessById(String id);
  Stream<List<BusinessModel>> watchAllBusinesses();
  Future<String> createBusiness(BusinessModel business);
  Future<void> updateBusiness(BusinessModel business);
  Future<void> deleteBusiness(String id);
}
