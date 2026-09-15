import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfubwIuynJACMcXve9CE3l-vIFjP17oDU',
    appId: '1:606015288420:web:fa79b492fdc508454ddb71',
    messagingSenderId: '606015288420',
    projectId: 'myapps-tradingfcm',
    storageBucket: 'myapps-tradingfcm.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfubwIuynJACMcXve9CE3l-vIFjP17oDU',
    appId: '1:606015288420:android:fa79b492fdc508454ddb71',
    messagingSenderId: '606015288420',
    projectId: 'myapps-tradingfcm',
    storageBucket: 'myapps-tradingfcm.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCfubwIuynJACMcXve9CE3l-vIFjP17oDU',
    appId: '1:606015288420:ios:fa79b492fdc508454ddb71',
    messagingSenderId: '606015288420',
    projectId: 'myapps-tradingfcm',
    storageBucket: 'myapps-tradingfcm.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCfubwIuynJACMcXve9CE3l-vIFjP17oDU',
    appId: '1:606015288420:ios:fa79b492fdc508454ddb71',
    messagingSenderId: '606015288420',
    projectId: 'myapps-tradingfcm',
    storageBucket: 'myapps-tradingfcm.firebasestorage.app',
  );
}
