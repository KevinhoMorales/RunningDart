import '../utils/version_utils.dart';

class AppUpdateStatus {
  const AppUpdateStatus({
    required this.requiresUpdate,
    required this.currentVersion,
    required this.requiredVersion,
  });

  final bool requiresUpdate;
  final String currentVersion;
  final String requiredVersion;
}

abstract class AppVersionService {
  Future<AppUpdateStatus> checkForRequiredUpdate();
}

class NoOpAppVersionService implements AppVersionService {
  const NoOpAppVersionService({this.currentVersion = '1.0.0'});

  final String currentVersion;

  @override
  Future<AppUpdateStatus> checkForRequiredUpdate() async {
    return AppUpdateStatus(
      requiresUpdate: false,
      currentVersion: currentVersion,
      requiredVersion: currentVersion,
    );
  }
}
