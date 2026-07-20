import '../models/business_model.dart';
import 'business_service.dart';

class MockBusinessService implements BusinessService {
  static const _mockBusinesses = [
    BusinessModel(
      id: 'biz-001',
      name: 'Café Central',
      description:
          'Cafetería artesanal con granos de origen local y ambiente acogedor.',
      address: 'Av. Principal 123, Centro',
      phone: '+593 99 123 4567',
      hours: 'Lun - Vie: 7:00 - 20:00 | Sáb - Dom: 8:00 - 18:00',
      category: 'café',
      benefits: ['10% de descuento en bebidas', 'Café de cortesía los lunes'],
      discount: '10% en bebidas',
      latitude: -0.22015,
      longitude: -78.51238,
    ),
    BusinessModel(
      id: 'biz-002',
      name: 'Gym FitZone',
      description:
          'Gimnasio moderno con equipos de última generación y clases grupales.',
      address: 'Calle Deportiva 45, Norte',
      phone: '+593 98 765 4321',
      hours: 'Lun - Dom: 5:00 - 22:00',
      category: 'gimnasio',
      benefits: ['1 mes gratis al registrarte', 'Acceso a clases premium'],
      discount: '1 mes gratis',
      latitude: -0.17542,
      longitude: -78.48021,
    ),
    BusinessModel(
      id: 'biz-003',
      name: 'Restaurante La Plaza',
      description:
          'Cocina tradicional con toques contemporáneos en el corazón de la ciudad.',
      address: 'Plaza Mayor 78, Centro Histórico',
      phone: '+593 97 555 1234',
      hours: 'Mar - Dom: 12:00 - 23:00',
      category: 'restaurante',
      benefits: ['Postre gratis con plato principal', '15% en almuerzos'],
      discount: '15% en almuerzos',
      latitude: -0.22082,
      longitude: -78.50247,
    ),
    BusinessModel(
      id: 'biz-004',
      name: 'Farmacia Vida Sana',
      description:
          'Farmacia con productos naturales, suplementos y atención personalizada.',
      address: 'Av. Salud 200, Sur',
      phone: '+593 96 444 7890',
      hours: 'Lun - Sáb: 8:00 - 21:00 | Dom: 9:00 - 14:00',
      category: 'salud',
      benefits: ['5% en productos naturales', 'Consulta nutricional gratuita'],
      discount: '5% en productos naturales',
      latitude: -0.25103,
      longitude: -78.52391,
    ),
    BusinessModel(
      id: 'biz-005',
      name: 'SportWear Pro',
      description:
          'Tienda especializada en ropa y accesorios deportivos de marcas premium.',
      address: 'Mall del Sol, Local 15',
      phone: '+593 95 333 2211',
      hours: 'Lun - Dom: 10:00 - 21:00',
      category: 'retail',
      benefits: ['20% en la primera compra', 'Envío gratis en compras +\$50'],
      discount: '20% primera compra',
      latitude: -0.17598,
      longitude: -78.46735,
    ),
    BusinessModel(
      id: 'biz-006',
      name: 'Yoga & Wellness Studio',
      description:
          'Estudio de yoga, meditación y bienestar integral para cuerpo y mente.',
      address: 'Calle Tranquila 33, Este',
      phone: '+593 94 222 3344',
      hours: 'Lun - Vie: 6:00 - 21:00 | Sáb: 8:00 - 14:00',
      category: 'salud',
      benefits: ['Clase de prueba gratis', '10% en membresías mensuales'],
      discount: '10% en membresías',
      latitude: -0.19674,
      longitude: -78.48962,
    ),
    BusinessModel(
      id: 'biz-007',
      name: 'Burger House',
      description:
          'Hamburguesas gourmet con ingredientes frescos y opciones vegetarianas.',
      address: 'Av. Gastronómica 56, Oeste',
      phone: '+593 93 111 5566',
      hours: 'Mié - Lun: 11:00 - 23:00',
      category: 'restaurante',
      benefits: ['Combo especial miembros', 'Bebida gratis en combos'],
      discount: 'Bebida gratis en combos',
      latitude: -0.20318,
      longitude: -78.49107,
    ),
    BusinessModel(
      id: 'biz-008',
      name: 'Espresso Lab',
      description:
          'Laboratorio de café de especialidad con métodos de extracción únicos.',
      address: 'Barrio Creativo 12, Centro',
      phone: '+593 92 888 9900',
      hours: 'Lun - Sáb: 8:00 - 19:00',
      category: 'café',
      benefits: ['Degustación mensual gratis', '8% de descuento permanente'],
      discount: '8% de descuento',
      latitude: -0.21456,
      longitude: -78.50588,
    ),
  ];

  @override
  Future<List<BusinessModel>> getBusinesses({String? category}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (category == null || category == 'Todos') {
      return List.unmodifiable(_mockBusinesses);
    }

    return _mockBusinesses
        .where((business) => business.category == category)
        .toList(growable: false);
  }

  @override
  Future<BusinessModel?> getBusinessById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      return _mockBusinesses.firstWhere((business) => business.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<BusinessModel>> watchAllBusinesses() async* {
    yield await getBusinesses();
  }

  @override
  Future<String> createBusiness(BusinessModel business) async {
    throw UnsupportedError('MockBusinessService does not support create.');
  }

  @override
  Future<void> updateBusiness(BusinessModel business) async {
    throw UnsupportedError('MockBusinessService does not support update.');
  }

  @override
  Future<void> deleteBusiness(String id) async {
    throw UnsupportedError('MockBusinessService does not support delete.');
  }
}
