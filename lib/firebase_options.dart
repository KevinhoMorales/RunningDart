import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'config/app_environment.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        AppEnvironment.isDev ? androidDev : androidProd,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => ios,
      _ => throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        ),
    };
  }

  static const FirebaseOptions androidProd = FirebaseOptions(
    apiKey: 'AIzaSyC5szNCYhw3S6yJl5EoRyLZXke6DhgYuuw',
    appId: '1:665721194102:android:75743e57bc0d97160ac157',
    messagingSenderId: '665721194102',
    projectId: 'running-dart',
    storageBucket: 'running-dart.firebasestorage.app',
  );

  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'AIzaSyC5szNCYhw3S6yJl5EoRyLZXke6DhgYuuw',
    appId: '1:665721194102:android:2e92e4dca78077790ac157',
    messagingSenderId: '665721194102',
    projectId: 'running-dart',
    storageBucket: 'running-dart.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAfW-h9iYCal0P6I0RqF-mXyR7HtUTJqpU',
    appId: '1:665721194102:ios:e09b1adcbc015eaf0ac157',
    messagingSenderId: '665721194102',
    projectId: 'running-dart',
    storageBucket: 'running-dart.firebasestorage.app',
    iosBundleId: 'com.devlokos.runningdart',
  );
}
