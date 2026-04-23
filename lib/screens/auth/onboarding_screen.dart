import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedGoal = "Reduce Social Media Addiction";
  List<String> _selectedPrefs = [];

  final List<String> _goals = [
    "Reduce Social Media Addiction",
    "Improve Sleep Quality",
    "Boost Work Productivity",
    "Mental Clarity & Peace",
    "Full Social Detox"
  ];

  final List<String> _prefOptions = ["Focus", "Sleep", "Work productivity", "Social detox"];

  Future<void> _completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final deviceInfo = DeviceInfoPlugin();
    String dId = "Unknown";
    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      dId = androidInfo.id;
    }

    await FirebaseFirestore.instance.collection('usersData').doc(user.uid).set({
      'name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 20,
      'phone': _phoneController.text.trim(),
      'email': user.email,
      'goal': _selectedGoal,
      'preferences': _selectedPrefs,
      'currentStreak': 0,
      'maxStreak': 0,
      'lastActionDate': FieldValue.serverTimestamp(),
      'deviceId': dId,
    }, SetOptions(merge: true));

    if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: _currentStep >= i ? AppTheme.cyan : Colors.white10, borderRadius: BorderRadius.circular(2)),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStep1Identity(),
                  _buildStep2Goals(),
                  _buildStep3Preferences(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0) TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('BACK', style: TextStyle(color: AppTheme.textMuted))) else const SizedBox(),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStep < 2) {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        _completeOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyan, foregroundColor: AppTheme.darkBlue, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
                    child: Text(_currentStep == 2 ? 'FINISH' : 'NEXT'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Identity() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Identity', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 8),
          const Text('How should the sanctuary address you?', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 40),
          _inputField(_nameController, 'Full Name', Icons.person_outline),
          const SizedBox(height: 20),
          _inputField(_ageController, 'Age', Icons.cake_outlined, keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          _inputField(_phoneController, 'Phone Number', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
        ],
      ),
    );
  }

  Widget _buildStep2Goals() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Purpose', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 8),
          const Text('What is your primary focus for this journey?', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 40),
          ..._goals.map((goal) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: _selectedGoal == goal ? AppTheme.cyan.withOpacity(0.1) : AppTheme.cardBlue, borderRadius: BorderRadius.circular(16), border: Border.all(color: _selectedGoal == goal ? AppTheme.cyan : Colors.transparent)),
            child: RadioListTile<String>(
              title: Text(goal, style: TextStyle(color: _selectedGoal == goal ? AppTheme.cyan : AppTheme.textLight, fontSize: 14)),
              value: goal,
              groupValue: _selectedGoal,
              onChanged: (v) => setState(() => _selectedGoal = v!),
              activeColor: AppTheme.cyan,
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildStep3Preferences() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personalize', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 8),
          const Text('Select your focus areas.', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _prefOptions.map((opt) {
              final isSelected = _selectedPrefs.contains(opt);
              return FilterChip(
                label: Text(opt),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) _selectedPrefs.add(opt); else _selectedPrefs.remove(opt);
                  });
                },
                selectedColor: AppTheme.cyan,
                checkmarkColor: AppTheme.darkBlue,
                labelStyle: TextStyle(color: isSelected ? AppTheme.darkBlue : AppTheme.textLight),
                backgroundColor: AppTheme.cardBlue,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textLight),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppTheme.cyan),
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.cardBlue,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}
