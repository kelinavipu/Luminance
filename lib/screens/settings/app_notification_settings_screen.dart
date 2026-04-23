import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';

class AppNotificationSettingsScreen extends StatefulWidget {
  const AppNotificationSettingsScreen({super.key});

  @override
  State<AppNotificationSettingsScreen> createState() => _AppNotificationSettingsScreenState();
}

class _AppNotificationSettingsScreenState extends State<AppNotificationSettingsScreen> {
  List<AppInfo> _apps = [];
  Map<String, dynamic> _appSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppsAndSettings();
  }

  Future<void> _loadAppsAndSettings() async {
    final apps = await InstalledApps.getInstalledApps(true, true);
    
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_notification_settings') ?? '{}';
    
    setState(() {
      _apps = apps;
      _appSettings = jsonDecode(settingsJson);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_notification_settings', jsonEncode(_appSettings));
  }

  void _toggleApp(String packageName, bool enabled) {
    setState(() {
      if (!_appSettings.containsKey(packageName)) {
        _appSettings[packageName] = {'enabled': enabled, 'h': 0, 'm': 0, 's': 10};
      } else {
        _appSettings[packageName]['enabled'] = enabled;
      }
    });
    _saveSettings();
  }

  void _updateTimer(String packageName, int h, int m, int s) {
    setState(() {
      if (!_appSettings.containsKey(packageName)) {
        _appSettings[packageName] = {'enabled': false, 'h': h, 'm': m, 's': s};
      } else {
        _appSettings[packageName]['h'] = h;
        _appSettings[packageName]['m'] = m;
        _appSettings[packageName]['s'] = s;
      }
    });
    _saveSettings();
  }

  void _showTimerPicker(String packageName, String appName) {
    final current = _appSettings[packageName] ?? {'h': 0, 'm': 0, 's': 10};
    final hController = TextEditingController(text: current['h'].toString());
    final mController = TextEditingController(text: current['m'].toString());
    final sController = TextEditingController(text: current['s'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBlue,
          title: Text('Timer for $appName', style: const TextStyle(color: AppTheme.textLight)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _timeInput(hController, 'HH'),
              _timeInput(mController, 'MM'),
              _timeInput(sController, 'SS'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
            TextButton(
              onPressed: () {
                int h = int.tryParse(hController.text) ?? 0;
                int m = int.tryParse(mController.text) ?? 0;
                int s = int.tryParse(sController.text) ?? 10;
                if (h == 0 && m == 0 && s < 10) s = 10; // Min limit 10s
                _updateTimer(packageName, h, m, s);
                Navigator.pop(context);
              },
              child: const Text('Set', style: TextStyle(color: AppTheme.cyan)),
            ),
          ],
        );
      }
    );
  }

  Widget _timeInput(TextEditingController controller, String label) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textLight),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textMuted),
          border: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.textMuted)),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.textMuted)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.cyan)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Reminders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _apps.length,
              itemBuilder: (context, index) {
                final app = _apps[index];
                final settings = _appSettings[app.packageName] ?? {'enabled': false, 'h': 0, 'm': 0, 's': 10};
                final bool isEnabled = settings['enabled'] ?? false;
                final String timeText = "${settings['h']}h ${settings['m']}m ${settings['s']}s";

                return ListTile(
                  leading: app.icon != null 
                      ? Image.memory(app.icon!, width: 40, height: 40)
                      : const Icon(Icons.android, color: AppTheme.cyan),
                  title: Text(app.name ?? 'Unknown', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                  subtitle: Text('Remind every $timeText', style: TextStyle(color: isEnabled ? AppTheme.cyan : AppTheme.textMuted, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.timer_outlined, color: AppTheme.cyan),
                        onPressed: () => _showTimerPicker(app.packageName!, app.name!),
                      ),
                      Switch(
                        value: isEnabled,
                        onChanged: (val) => _toggleApp(app.packageName!, val),
                        activeColor: AppTheme.cyan,
                        activeTrackColor: AppTheme.cyan.withOpacity(0.3),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkBlue,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () {
            _saveSettings();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification settings saved!'), backgroundColor: AppTheme.cyan),
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cyan,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('SAVE REMINDERS'),
        ),
      ),
    );
  }
}
