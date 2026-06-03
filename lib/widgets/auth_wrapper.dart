import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth.dart';
import '../services/biometric_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

// 1. KONTROLLIME, KAS KASUTAJA ON LOGITUD SISSE
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const BiometricCheckWrapper();
        }

        return const LoginScreen();
      },
    );
  }
}

// 2. KUI ON LOGITUD, KONTROLLIME SÕRMEJÄLGE / NÄOTUVASTUST
class BiometricCheckWrapper extends StatefulWidget {
  const BiometricCheckWrapper({super.key});

  @override
  State<BiometricCheckWrapper> createState() => _BiometricCheckWrapperState();
}

class _BiometricCheckWrapperState extends State<BiometricCheckWrapper> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticated = false;
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  void _checkBiometrics() async {
    bool available = await _biometricService.isBiometricAvailable();
    if (available) {
      bool success = await _biometricService.authenticate();
      setState(() {
        _isAuthenticated = success;
        _hasChecked = true;
      });
    } else {
      setState(() {
        _isAuthenticated = true;
        _hasChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const HomeScreen();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('App is locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkBiometrics,
              child: const Text('Try Again'),
            ),
            TextButton(
              onPressed: () => AuthService().signOut(),
              child: const Text('Sign in with different account', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}