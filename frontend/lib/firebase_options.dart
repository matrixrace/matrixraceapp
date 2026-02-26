import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configurações do Firebase geradas manualmente
/// Projeto: matrixapp-v3
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não configurado para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyK1vcEHyRKdfFz9ILuaPnMXVt_tMVOMc',
    appId: '1:596396881340:web:b683f39fe90c87c2e8a7b9',
    messagingSenderId: '596396881340',
    projectId: 'matrixapp-v3',
    authDomain: 'matrixapp-v3.firebaseapp.com',
    storageBucket: 'matrixapp-v3.firebasestorage.app',
    measurementId: 'G-1PNY697T19',
  );

  // Android e iOS usam a mesma config web por enquanto
  // Quando você criar os apps nativos no Firebase, atualize aqui
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAyK1vcEHyRKdfFz9ILuaPnMXVt_tMVOMc',
    appId: '1:596396881340:web:b683f39fe90c87c2e8a7b9',
    messagingSenderId: '596396881340',
    projectId: 'matrixapp-v3',
    authDomain: 'matrixapp-v3.firebaseapp.com',
    storageBucket: 'matrixapp-v3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAyK1vcEHyRKdfFz9ILuaPnMXVt_tMVOMc',
    appId: '1:596396881340:web:b683f39fe90c87c2e8a7b9',
    messagingSenderId: '596396881340',
    projectId: 'matrixapp-v3',
    authDomain: 'matrixapp-v3.firebaseapp.com',
    storageBucket: 'matrixapp-v3.firebasestorage.app',
    iosBundleId: 'com.f1predictions.f1Predictions',
  );
}
