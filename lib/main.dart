import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart'; 

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
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(), // Muudatus siin (ainult üks algusekraan)
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF181C14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181C14),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFECDFCC),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFFECDFCC)),
        ),
        
        // Üldine värviskeem (määrab ära kaardid, nupud jne)
        colorScheme: const ColorScheme.dark(
          surface:  Color(0xFF3C3D37),      // Elementide taust (3C3D37)
          primary: Color(0xFFECDFCC),      // Põhivärv / Tekstivärv (ECDFCC)
          secondary: Color(0xFF697565),    // Sekundaarne (697565)
        ),

        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFECDFCC)),
          bodyMedium: TextStyle(color: Color(0xFFECDFCC)),
        ),
      ),
    );
  }
}