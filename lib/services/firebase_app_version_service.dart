import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/constants.dart';
import '../utils/version_utils.dart';
import 'app_version_service.dart';

class FirebaseAppVersionService implements AppVersionService {
  FirebaseAppVersionService({
    FirebaseRemoteConfig? remoteConfig,
    PackageInfo? packageInfo,
  })  : _remoteConfig = remoteConfig,
        _packageInfo = packageInfo;

  final FirebaseRemoteConfig? _remoteConfig;
  final PackageInfo? _packageInfo;

  @override
  Future<AppUpdateStatus> checkForRequiredUpdate() async {
    final packageInfo = _packageInfo ?? await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final remoteConfig = _remoteConfig ?? FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        AppConstants.remoteConfigMinVersionKey: currentVersion,
      });
      await remoteConfig.fetchAndActivate();

      final requiredVersion = remoteConfig
          .getString(AppConstants.remoteConfigMinVersionKey)
          .trim();
      final normalizedRequired = requiredVersion.isEmpty
          ? currentVersion
          : requiredVersion;

      return AppUpdateStatus(
        requiresUpdate: VersionUtils.isUpdateRequired(
          currentVersion: currentVersion,
          requiredVersion: normalizedRequired,
        ),
        currentVersion: currentVersion,
        requiredVersion: normalizedRequired,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Remote Config version check failed: $error\n$stackTrace',
      );
      return AppUpdateStatus(
        requiresUpdate: false,
        currentVersion: currentVersion,
        requiredVersion: currentVersion,
      );
    }
  }
}
