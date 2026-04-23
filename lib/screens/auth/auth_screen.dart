import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<String?> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique ID for the device
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final deviceId = await _getDeviceId();
      if (deviceId == null) throw Exception("Could not identify device hardware.");

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Check if device is already registered to someone else
      final deviceQuery = await FirebaseFirestore.instance
          .collection('usersData')
          .where('deviceId', isEqualTo: deviceId)
          .get();

      if (deviceQuery.docs.isNotEmpty) {
        final existingUserEmail = deviceQuery.docs.first.get('email');
        if (existingUserEmail != email) {
          throw Exception("Hardware Locked: This device is already linked to $existingUserEmail. One device, one account.");
        }
      }

      // 2. Proceed with Auth
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } else {
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        
        // 3. Link device to new account
        await FirebaseFirestore.instance.collection('usersData').doc(cred.user!.uid).set({
          'email': email,
          'deviceId': deviceId,
          'createdAt': FieldValue.serverTimestamp(),
          'age': 20,
          'name': "Cloud Kid",
          'goal': "Reduce Addiction",
        }, SetOptions(merge: true));

        if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } catch (e) {
      String message = e.toString();
      if (message.contains(']')) message = message.split(']').last.trim();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/app_logo.png', width: 140, height: 140),
            const SizedBox(height: 16),
            Text(
              _isLogin ? 'Welcome Back' : 'Join Sanctuary',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            const Text(
              'One device. One account. Total peace.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 48),
            _buildTextField(_emailController, 'Email', Icons.email_outlined),
            const SizedBox(height: 24),
            _buildTextField(_passwordController, 'Password', Icons.lock_outline, obscure: true),
            const SizedBox(height: 48),
            if (_isLoading)
              const CircularProgressIndicator(color: AppTheme.cyan)
            else
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cyan,
                  foregroundColor: AppTheme.darkBlue,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_isLogin ? 'LOGIN' : 'SIGN UP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin ? 'New here? Create account' : 'Already have an account? Login',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textLight),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.cyan, size: 20),
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.cyan)),
        filled: true,
        fillColor: AppTheme.cardBlue.withOpacity(0.5),
      ),
    );
  }
}
