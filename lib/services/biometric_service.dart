import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  // check if device supports biometrics and if any biometric method is enrolled
  Future<bool> isBiometricAvailable() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();

      if (kDebugMode) {
        debugPrint('Biometric support: $isSupported');
        debugPrint('Available biometrics: $availableBiometrics');
      }

      return isSupported;
    } catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  // start biometric authentication
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate yourself to access the messages',
        persistAcrossBackgrounding:
            true, // keeps the authentication active even if the app goes to the background (Android)
        biometricOnly:
            true, // only allow biometric authentication, no PIN/pattern fallback
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
