import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/business_model.dart';
import 'package:running_dart/models/membership_modality.dart';
import 'package:running_dart/theme/category_style.dart';
import 'package:running_dart/utils/constants.dart';
import 'package:running_dart/utils/helpers.dart';
import 'package:running_dart/utils/membership_helpers.dart';

void main() {
  const officialProBusiness = BusinessModel(
    id: 'sample',
    name: 'Sample',
    description: 'Sample',
    address: 'Address',
    phone: '0999999999',
    hours: '9:00 - 18:00',
    category: 'salud',
    benefits: [],
    discount: '10%',
    applicableModalities: [
      MembershipModality.official,
      MembershipModality.proTeam,
    ],
  );

  group('Business categories', () {
    test('includes lifestyle and servicios in constants', () {
      expect(AppConstants.businessCategories, contains('lifestyle'));
      expect(AppConstants.businessCategories, contains('servicios'));
    });

    test('categoryLabel returns readable labels', () {
      expect(Helpers.categoryLabel('lifestyle'), 'Lifestyle');
      expect(Helpers.categoryLabel('servicios'), 'Servicios');
    });

    test('CategoryStyle provides icons for new categories', () {
      expect(CategoryStyle.iconFor('lifestyle'), isNotNull);
      expect(CategoryStyle.iconFor('servicios'), isNotNull);
    });

    test('isRestaurantCategory identifies restaurantes only', () {
      expect(Helpers.isRestaurantCategory('restaurante'), isTrue);
      expect(Helpers.isRestaurantCategory('café'), isFalse);
      expect(Helpers.isRestaurantCategory('salud'), isFalse);
    });

    test('isValidHttpUrl accepts https links only with scheme', () {
      expect(
        Helpers.isValidHttpUrl('https://meniuz.com/restaurante/demo'),
        isTrue,
      );
      expect(
        Helpers.isValidHttpUrl('http://meniuz.com/restaurante/demo'),
        isTrue,
      );
      expect(Helpers.isValidHttpUrl('meniuz.com/menu'), isFalse);
      expect(Helpers.isValidHttpUrl('not a url'), isFalse);
    });
  });

  group('BusinessModel meniuzMenuUrl', () {
    test('serializes meniuzMenuUrl in firestore payload when present', () {
      const business = BusinessModel(
        id: 'restaurant-1',
        name: 'Restaurante Demo',
        description: 'Desc',
        address: 'Calle 1',
        phone: '0999999999',
        hours: '9:00 - 18:00',
        category: 'restaurante',
        benefits: [],
        discount: '10%',
        meniuzMenuUrl: 'https://meniuz.com/restaurante/demo',
      );

      final payload = business.toFirestore();
      expect(payload['meniuzMenuUrl'], 'https://meniuz.com/restaurante/demo');
    });

    test('omits meniuzMenuUrl from firestore payload when empty', () {
      const business = BusinessModel(
        id: 'restaurant-1',
        name: 'Restaurante Demo',
        description: 'Desc',
        address: 'Calle 1',
        phone: '0999999999',
        hours: '9:00 - 18:00',
        category: 'restaurante',
        benefits: [],
        discount: '10%',
      );

      final payload = business.toFirestore();
      expect(payload.containsKey('meniuzMenuUrl'), isFalse);
    });

    test('reads meniuzMenuUrl from json', () {
      final business = BusinessModel.fromJson({
        'id': 'restaurant-1',
        'name': 'Restaurante Demo',
        'description': 'Desc',
        'address': 'Calle 1',
        'phone': '0999999999',
        'hours': '9:00 - 18:00',
        'category': 'restaurante',
        'benefits': [],
        'discount': '10%',
        'meniuzMenuUrl': 'https://meniuz.com/restaurante/demo',
      });

      expect(business.meniuzMenuUrl, 'https://meniuz.com/restaurante/demo');
    });
  });

  group('MembershipHelpers.canRedeemBusinessBenefits', () {
    test('community member cannot redeem official/pro benefits', () {
      expect(
        MembershipHelpers.canRedeemBusinessBenefits(
          canUseMembershipFeatures: true,
          membershipModality: MembershipModality.community,
          business: officialProBusiness,
        ),
        isFalse,
      );
    });

    test('official member can redeem official/pro benefits', () {
      expect(
        MembershipHelpers.canRedeemBusinessBenefits(
          canUseMembershipFeatures: true,
          membershipModality: MembershipModality.official,
          business: officialProBusiness,
        ),
        isTrue,
      );
    });

    test('inactive membership access cannot redeem benefits', () {
      expect(
        MembershipHelpers.canRedeemBusinessBenefits(
          canUseMembershipFeatures: false,
          membershipModality: MembershipModality.official,
          business: officialProBusiness,
        ),
        isFalse,
      );
    });
    test('admin can preview benefits regardless of modality', () {
      expect(
        MembershipHelpers.canRedeemBusinessBenefits(
          canUseMembershipFeatures: false,
          membershipModality: MembershipModality.community,
          business: officialProBusiness,
          isAdmin: true,
        ),
        isTrue,
      );
    });
  });
}
