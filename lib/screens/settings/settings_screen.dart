import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../utils/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/notification_service.dart';
import 'app_notification_settings_screen.dart';
import 'app_block_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _childMode = false;
  int _notificationInterval = 10;
  final String _childPin = "0000";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _childMode = prefs.getBool('childMode') ?? false;
      _notificationInterval = prefs.getInt('notificationInterval') ?? 10;
    });
  }

  Future<void> _toggleChildMode(bool value) async {
    if (!value) {
      _showPinDialog();
    } else {
      _enableChildMode();
    }
  }

  Future<void> _enableChildMode() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_block_settings') ?? '{}';
    final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
    final restrictedKeywords = ['instagram', 'facebook', 'tiktok', 'snapchat', 'game', 'pubg', 'freefire', 'clash'];
    
    settings.forEach((pkg, cfg) {
      if (restrictedKeywords.any((k) => pkg.toLowerCase().contains(k))) {
        settings[pkg]['enabled'] = true;
        settings[pkg]['h'] = 0;
        settings[pkg]['m'] = 0;
        settings[pkg]['s'] = 10;
      }
    });

    await prefs.setString('app_block_settings', jsonEncode(settings));
    await prefs.setBool('childMode', true);
    await prefs.setInt('notificationInterval', 5);

    Workmanager().registerPeriodicTask(
      "child_mode_reminder",
      "sarcasticReminder",
      frequency: const Duration(minutes: 5),
    );

    setState(() {
      _childMode = true;
      _notificationInterval = 5;
    });
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBlue,
        title: const Text('Security Verification', style: TextStyle(color: AppTheme.textLight)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(color: AppTheme.cyan, fontSize: 24, letterSpacing: 10),
          decoration: const InputDecoration(hintText: "ENTER PIN", hintStyle: TextStyle(fontSize: 12, letterSpacing: 1), counterText: ""),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text == _childPin) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('childMode', false);
                Workmanager().cancelByUniqueName("child_mode_reminder");
                setState(() => _childMode = false);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Security PIN')));
              }
            },
            child: const Text('CONFIRM'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 32),
          const Text('GUARDIAN CONTROLS', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.child_care_rounded,
            iconColor: AppTheme.cyan,
            title: 'Guardian Child Mode',
            subtitle: 'Automated restrictions & reminders',
            trailing: Switch(value: _childMode, onChanged: _toggleChildMode, activeColor: AppTheme.cyan),
          ),
          _buildSettingsTile(
            icon: Icons.security_rounded,
            iconColor: Colors.blueAccent,
            title: 'Device Setup Guide',
            subtitle: 'Critical persistence permissions',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            onTap: _showPermissionGuide,
          ),
          const SizedBox(height: 32),
          const Text('SYSTEM BOUNDARIES', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.orangeAccent,
            title: 'Alert Intervals',
            subtitle: 'Reminders every $_notificationInterval minutes',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppNotificationSettingsScreen())),
          ),
          _buildSettingsTile(
            icon: Icons.block_flipped,
            iconColor: Colors.redAccent,
            title: 'Iron Lock Blocker',
            subtitle: 'Managed daily application limits',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppBlockSettingsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return InkWell(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBlue,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.cardBlue,
                  backgroundImage: const AssetImage('assets/app_logo.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.email?.split('@').first.toUpperCase() ?? "LUMINANCE USER", style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text(user?.email ?? "Guest Mode", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppTheme.cyan, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPermissionGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Guardian Setup', style: TextStyle(color: AppTheme.textLight, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _guideItem(icon: Icons.track_changes, title: 'Usage Access', subtitle: 'Track screen time', onTap: () => const MethodChannel('com.luminance/usage').invokeMethod('requestUsagePermission')),
              _guideItem(icon: Icons.layers, title: 'Overlay Permission', subtitle: 'Enable Zen Lock screen', onTap: () => const AndroidIntent(action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION').launch()),
              _guideItem(icon: Icons.battery_saver, title: 'No Battery Restrictions', subtitle: 'Critical for Redmi/MIUI', onTap: () => const AndroidIntent(action: 'android.settings.APPLICATION_DETAILS_SETTINGS', arguments: {'android.provider.extra.APP_PACKAGE': 'com.luminance.luminance'}).launch()),
              _guideItem(icon: Icons.accessibility_new, title: 'Accessibility Service', subtitle: 'Required for active blocking', onTap: () => const MethodChannel('com.luminance/usage').invokeMethod('requestAccessibilityPermission')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.cyan),
      title: Text(title, style: const TextStyle(color: AppTheme.textLight)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _buildSettingsTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor)),
      title: Text(title, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
