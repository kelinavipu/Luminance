import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic> _userData = {};
  String _deviceId = "Loading...";
  bool _isLoading = true;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('usersData').doc(user?.uid).get();
      final deviceInfo = DeviceInfoPlugin();
      String dId = "Unknown";
      if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        dId = androidInfo.id;
      }

      setState(() {
        _userData = doc.data() ?? {};
        _nameController.text = _userData['name'] ?? '';
        _ageController.text = (_userData['age'] ?? 20).toString();
        _phoneController.text = _userData['phone'] ?? '';
        _goalController.text = _userData['goal'] ?? '';
        _deviceId = dId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('usersData').doc(user?.uid).update({
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 20,
      'phone': _phoneController.text.trim(),
      'goal': _goalController.text.trim(),
    });
    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sanctuary Identity Updated'), backgroundColor: AppTheme.cyan));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Identity'), 
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
              if (_isEditing) _saveProfile(); else setState(() => _isEditing = true);
            }, 
            icon: Icon(_isEditing ? Icons.check_circle : Icons.edit, color: AppTheme.cyan)
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(radius: 60, backgroundColor: AppTheme.cardBlue, backgroundImage: const AssetImage('assets/app_logo.png')),
                      const CircleAvatar(radius: 18, backgroundColor: AppTheme.cyan, child: Icon(Icons.verified, color: AppTheme.darkBlue, size: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                if (!_isEditing) ...[
                  Text(_userData['name'] ?? 'Luminance User', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                  Text(user?.email ?? '', style: const TextStyle(color: AppTheme.textMuted)),
                ],
                const SizedBox(height: 40),
                
                _buildField('Full Name', _nameController, Icons.person_outline, _isEditing),
                _buildField('Age', _ageController, Icons.cake_outlined, _isEditing, keyboardType: TextInputType.number),
                _buildField('Wellbeing Goal', _goalController, Icons.track_changes, _isEditing),
                _buildField('Phone Bind', _phoneController, Icons.phone_android, _isEditing, keyboardType: TextInputType.phone),
                
                if (!_isEditing) ...[
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text('SECURITY & HARDWARE', style: TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, color: AppTheme.textMuted),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hardware ID (H-ID)', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                              Text(_deviceId, style: const TextStyle(color: AppTheme.textLight, fontSize: 13, fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                        const Icon(Icons.lock_outline, color: AppTheme.cyan, size: 16),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 48),
                TextButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Sign Out of Sanctuary', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, bool editing, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.cyan, size: 24),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                editing 
                  ? TextField(
                      controller: controller, 
                      keyboardType: keyboardType,
                      style: const TextStyle(color: AppTheme.textLight, fontSize: 16),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    )
                  : Text(controller.text, style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
