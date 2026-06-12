import 'package:flutter/material.dart';
import '../services/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  final Color _primaryColor = const Color(0xFF6366F1);     
  final Color _backgroundColor = const Color(0xFF0F172A); 
  final Color _cardColor = const Color(0xFF1E293B);       
  final Color _textColor = const Color(0xFFF8FAFC); 

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _auth.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('] ') 
            ? e.toString().split('] ').last 
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLogin ? Icons.lock_open_rounded : Icons.person_add_rounded,
                      size: 50,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Sign in to continue your secure chats' : 'Get started by creating a new account',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: _textColor), 
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.grey[400]),
                      filled: true,
                      fillColor: _cardColor, 
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _primaryColor, width: 2), 
                      ),
                    ),
                    validator: (val) => val!.isEmpty ? 'Please enter your email' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey[400]),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey[400],
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: _cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                    ),
                    validator: (val) => val!.length < 6 ? 'Password must be at least 6 characters long' : null,
                  ),
                  
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _isLogin ? 'Log In' : 'Create Account',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = '';
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        children: [
                          TextSpan(text: _isLogin ? "Don't have an account? " : "Already have an account? "),
                          TextSpan(
                            text: _isLogin ? "Register" : "Log In",
                            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}