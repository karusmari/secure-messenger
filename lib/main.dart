import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'services/biometric_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Messenger',
      theme: ThemeData.dark(), 
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

// What to show based on the authentication state of the user
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    // StreamBuilder is listening if the user is logged in or not and shows the appropriate screen
    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        // if the connection is still waiting for data, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // if the user is logged in, show the HomeScreen
        if (snapshot.hasData) {
          return const BiometricCheckWrapper();
        }

        // if no user is logged in, show the LoginScreen
        return const LoginScreen();
      },
    );
  }
}

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
      // Kui seadmel pole biomeetriat (nt vana telefon või simulaator), lubame otse sisse
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

    // Kui läbis kontrolli, pääseb Pealehele
    if (_isAuthenticated) {
      return const HomeScreen();
    }

    // Kui tühistas või ebaõnnestus, näitame nuppu, et uuesti proovida või välja logida
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