import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth.dart';
import '../services/biometric_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

// check if user is logged in or not, and show the appropriate screen
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

//in case of log in we check the biometrics
class BiometricCheckWrapper extends StatefulWidget {
  const BiometricCheckWrapper({super.key});

  @override
  State<BiometricCheckWrapper> createState() => _BiometricCheckWrapperState();
}

class _BiometricCheckWrapperState extends State<BiometricCheckWrapper> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticated = false;
  bool _hasChecked = false;
  bool _isCheckingNow = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics(autoStart: true);
  }

  @override
  void reassemble() {
    super.reassemble();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticated = false;
      _hasChecked = false;
      _isCheckingNow = false;
    });

    _checkBiometrics(autoStart: false);
  }

  void _checkBiometrics({bool autoStart = false}) async {
    if (_isCheckingNow) return;

    setState(() {
      _isCheckingNow = true;
    });

    bool available = await _biometricService.isBiometricAvailable();
    if (available) {

      bool success = await _biometricService.authenticate();
      setState(() {
        _isAuthenticated = success;
        _hasChecked = true;
        _isCheckingNow = false;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _hasChecked = true;
        _isCheckingNow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAuthenticated) {
      return const HomeScreen();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 16),
            const Text(
              'Secure Messenger is Locked',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Authentication failed or cancelled.',
              style: TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () => _checkBiometrics(autoStart: false),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => AuthService().signOut(),
              child: const Text(
                'Sign in with different account',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}