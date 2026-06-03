import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // Kontrolli, kas seade üldse toetab biomeetriat ja kas kasutaja on selle seadistanud
  Future<bool> isBiometricAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate =
        canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  // Käivita kontroll (FaceID / Sõrmejälg)
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate yourself to access the messages',
        persistAcrossBackgrounding:
            true, // Hoiab autentimise akna alles, kui äpp läheb taustale
        biometricOnly: true, // Ei luba paroodi/PIN koodi, ainult biomeetria
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication Required',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(cancelButton: 'Cancel'),
        ],
      );
    } catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    }
  }
}
