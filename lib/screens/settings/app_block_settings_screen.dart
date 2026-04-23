import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_data_service.dart';

class AppBlockSettingsScreen extends StatefulWidget {
  const AppBlockSettingsScreen({super.key});

  @override
  State<AppBlockSettingsScreen> createState() => _AppBlockSettingsScreenState();
}

class _AppBlockSettingsScreenState extends State<AppBlockSettingsScreen> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filteredApps = [];
  Map<String, dynamic> _blockSettings = {};
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadAppsAndSettings();
  }

  Future<void> _loadAppsAndSettings() async {
    final apps = await InstalledApps.getInstalledApps(true, true);
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('app_block_settings') ?? '{}';
    
    setState(() {
      _apps = apps;
      _filteredApps = apps;
      _blockSettings = jsonDecode(settingsJson);
      _isLoading = false;
    });
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _apps.where((app) => 
        app.name?.toLowerCase().contains(query.toLowerCase()) ?? false
      ).toList();
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_block_settings', jsonEncode(_blockSettings));
    await DashboardDataService().loadAllData();
  }

  void _toggleApp(String packageName, bool enabled) {
    setState(() {
      if (!_blockSettings.containsKey(packageName)) {
        _blockSettings[packageName] = {'enabled': enabled, 'h': 0, 'm': 30, 's': 0};
      } else {
        _blockSettings[packageName]['enabled'] = enabled;
      }
    });
    _saveSettings();
  }

  void _updateTimer(String packageName, int h, int m, int s) {
    setState(() {
      if (!_blockSettings.containsKey(packageName)) {
        _blockSettings[packageName] = {'enabled': false, 'h': h, 'm': m, 's': s};
      } else {
        _blockSettings[packageName]['h'] = h;
        _blockSettings[packageName]['m'] = m;
        _blockSettings[packageName]['s'] = s;
      }
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Blocker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: _filterApps,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                filled: true,
                fillColor: AppTheme.cardBlue,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              children: [
                _buildBatteryWarning(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final settings = _blockSettings[app.packageName] ?? {'enabled': false, 'h': 0, 'm': 30, 's': 0};
                      final bool isEnabled = settings['enabled'] ?? false;
                      // Using V2 to force compiler refresh
                      return _buildAppTileV2(app.packageName!, app.name!, isEnabled, settings);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBatteryWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_alert, color: Colors.redAccent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Redmi Users: Set Battery to "No Restrictions" for the blocker to stay active.',
              style: TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTileV2(String pkg, String name, bool enabled, Map<String, dynamic> time) {
    final suggestion = DashboardDataService().getSuggestedLimit(pkg);
    final String suggStr = "${suggestion['h']}h ${suggestion['m']}m";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.android, color: enabled ? AppTheme.cyan : AppTheme.textMuted)),
        title: Text(name, style: const TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${time['h']}h ${time['m']}m limit', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('AI Suggests: $suggStr', style: const TextStyle(color: AppTheme.cyan, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.timer_outlined, color: AppTheme.cyan, size: 20), onPressed: () => _showTimerPicker(pkg, name)),
            Switch(value: enabled, onChanged: (v) => _toggleApp(pkg, v), activeColor: AppTheme.cyan),
          ],
        ),
      ),
    );
  }

  void _showTimerPicker(String packageName, String appName) {
    final current = _blockSettings[packageName] ?? {'h': 0, 'm': 30, 's': 0};
    final hController = TextEditingController(text: current['h'].toString());
    final mController = TextEditingController(text: current['m'].toString());
    
    final suggestion = DashboardDataService().getSuggestedLimit(packageName);
    final String suggestionText = "${suggestion['h']}h ${suggestion['m']}m";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBlue,
        title: Text('Daily Limit for $appName', style: const TextStyle(color: AppTheme.textLight, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined, color: AppTheme.cyan, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Luminance Suggested: $suggestionText',
                      style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _timeInput(hController, 'Hours'),
                const SizedBox(width: 16),
                _timeInput(mController, 'Minutes'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Based on your weekly behavior.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () {
              _updateTimer(packageName, int.tryParse(hController.text) ?? 0, int.tryParse(mController.text) ?? 0, 0);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _timeInput(TextEditingController controller, String label) {
    return SizedBox(
      width: 70,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.3))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.darkBlue, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: ElevatedButton(
        onPressed: () {
          _saveSettings();
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: const Text('FINALIZE LIMITS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }
}
