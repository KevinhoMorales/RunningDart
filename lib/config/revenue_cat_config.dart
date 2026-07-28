/// Identifiers and public keys for RevenueCat.
///
/// Keep the entitlement / product identifiers aligned with the RevenueCat
/// dashboard (Project → Product catalog). The public SDK key is safe to ship
/// in the client; never put the secret REST API key here.
class RevenueCatConfig {
  RevenueCatConfig._();

  /// Public SDK key from RevenueCat (test key until App Store / Play are live).
  static const String apiKey = 'test_qYIETarvOArlYLhqTAgRrCXGPcY';

  /// Entitlement that unlocks SAINTS Pro Team digital benefits.
  static const String proEntitlementId = 'SAINTS: Wellness Club Pro';

  /// App Store / Play product attached to the Pro entitlement (monthly).
  static const String proTeamMonthlyProductId = 'PRO TEAM (monthly)';
}
