import 'package:flutter/material.dart';

import '../config/app_environment.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppEnvironment.isProd) {
      return child;
    }

    return Banner(
      message: 'DEV',
      location: BannerLocation.topStart,
      color: Colors.orange,
      textStyle: const TextStyle(
        color: Colors.black,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
      child: child,
    );
  }
}
