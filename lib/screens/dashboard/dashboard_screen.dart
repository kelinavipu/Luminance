import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import 'dashboard_data_service.dart';
import 'breathing_lotus.dart';
import '../../utils/mock_data_seeder.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  final DashboardDataService _dataService = DashboardDataService();
  int _currentPageIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _dataService.loadAllData();
    _dataService.fetchGroqInference().then((_) { if (mounted) setState(() {}); });
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _seedAndRefresh() async {
    setState(() => _isLoading = true);
    await MockDataSeeder.seedUsageHistory();
    await _dataService.loadAllData();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analytical History Synced!'), backgroundColor: AppTheme.cyan));
    }
  }

  void _showRiskScoreAudit() {
    final score = _dataService.penaltyScore.round();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFF0F1B2E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Text('Risk Score: $score%', style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('WHAT CONTRIBUTED', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              _riskItem('Screen Time (${(_dataService.totalScreenTimeHours).toInt()} min)', '+${_dataService.penaltyBreakdown['Over Usage']?.round() ?? 0} pts', (_dataService.totalScreenTimeHours / 480).clamp(0.0, 1.0), Colors.redAccent),
              _riskItem('Wasteful App Usage (${_dataService.guiltIndex.toInt()}%)', '+${_dataService.penaltyBreakdown['Wasteful Binging']?.round() ?? 0} pts', (_dataService.guiltIndex / 100).clamp(0.0, 1.0), AppTheme.cyan),
              _riskItem('Night Usage (detected)', '+${_dataService.penaltyBreakdown['Night Usage']?.round() ?? 0} pts', _dataService.nightAppsOpened > 0 ? 0.8 : 0.1, Colors.redAccent),
              _riskItem('Phone Unlocks (${_dataService.unlockCount})', '+${_dataService.penaltyBreakdown['Pickups']?.round() ?? 0} pts', (_dataService.unlockCount / 100).clamp(0.0, 1.0), Colors.orangeAccent),
              
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Risk Score', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                  Text('$score / 100', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 32),
              Center(child: Text(score > 50 ? 'OH!' : 'GOOD', style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w900))),
              const SizedBox(height: 16),
              Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('DISMISS', style: TextStyle(color: AppTheme.textMuted)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riskItem(String label, String pts, double val, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: AppTheme.textLight, fontSize: 13)), Text(pts, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: val, minHeight: 6, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(color))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A121E),
      appBar: AppBar(
        title: const Text('Usage Dashboard'),
        actions: [IconButton(onPressed: _seedAndRefresh, icon: const Icon(Icons.sync_rounded, color: AppTheme.cyan))],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
        : Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPageIndex = index),
                  children: [
                    _buildSlider1Usage(),
                    _buildSlider2Streaks(),
                    _buildSlider3RiskOverview(),
                    _buildSlider4CategoryBreakdown(),
                    _buildSlider5DetailedTrends(),
                    _buildSlider6AppsToday(),
                  ],
                ),
              ),
              _buildPageIndicator(),
              const SizedBox(height: 16),
            ],
          ),
    );
  }

  Widget _buildSlider1Usage() {
    final h = (_dataService.totalScreenTimeHours / 60).toInt();
    final m = (_dataService.totalScreenTimeHours % 60).toInt();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Stack(
            alignment: Alignment.center,
            children: [
              const BreathingLotus(size: 280, color: AppTheme.cyan),
              Column(
                children: [
                  const Text('TOTAL TIME', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, letterSpacing: 1.5)),
                  Text('${h}h ${m}m', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildGuiltCard(),
          const SizedBox(height: 20),
          _buildStreakSetCard(),
        ],
      ),
    );
  }

  Widget _buildGuiltCard() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(32), border: Border.all(color: AppTheme.cyan.withOpacity(0.1))),
      child: Column(
        children: [
          const Text('GUILT INDEX', style: TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text('${_dataService.guiltIndex.round()}%', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 8),
          Text(_dataService.guiltIndex > 40 ? "Distracted." : "You're in control.", style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStreakSetCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STREAK', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)), Text('${_dataService.currentStreak} DAYS', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight))]),
          ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/settings'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyan.withOpacity(0.1), foregroundColor: AppTheme.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Set Limits')),
        ],
      ),
    );
  }

  Widget _buildSlider2Streaks() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Streaks Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const Text('Your commitment inferences', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 32),
          _buildMaxStreakCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _statCard('Tasks Done', '${_dataService.totalTasksCompleted}', Icons.check_circle_outline, AppTheme.cyan)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Glow Days', '${_dataService.glowDays}', Icons.star_outline, Colors.orangeAccent)),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Inference', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 12),
          Text(_dataService.aiInference, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPresenceMatrix() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          bool active = _dataService.presenceMatrix[i];
          return Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppTheme.cyan : Colors.white10,
                  boxShadow: active ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)] : [],
                ),
              ),
              const SizedBox(height: 8),
              Text('D${i + 1}', style: TextStyle(color: active ? AppTheme.textLight : AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMaxStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.cyan.withOpacity(0.2))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Max Streak', style: TextStyle(color: AppTheme.textMuted)), Text('${_dataService.maxStreak} Days', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight))]),
          const Icon(Icons.whatshot, color: Colors.orangeAccent, size: 48),
        ],
      ),
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSlider3RiskOverview() {
    return InkWell(
      onTap: _showRiskScoreAudit,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Risk Assessment', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const Text('Tap to audit your points', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 40),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 200, height: 200, child: CircularProgressIndicator(value: _dataService.penaltyScore / 100, strokeWidth: 16, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(_dataService.penaltyScore > 50 ? Colors.redAccent : AppTheme.cyan))),
                  Column(children: [Text('${_dataService.penaltyScore.round()}%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.textLight)), const Text('RISK', style: TextStyle(color: AppTheme.textMuted, letterSpacing: 2))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider4CategoryBreakdown() {
    final keys = _dataService.categoryBreakdown.keys.toList();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Breakdown', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 32),
          Expanded(child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: 100, titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(keys[v.toInt()].substring(0, 3), style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)))))), borderData: FlBorderData(show: false), barGroups: List.generate(keys.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: (_dataService.categoryBreakdown[keys[i]]! / max(1, _dataService.totalScreenTimeHours)) * 100, color: AppTheme.cyan, width: 16, borderRadius: BorderRadius.circular(4))]))))),
          const SizedBox(height: 24),
          Row(children: [Expanded(child: _benchmarkCard('Weekly Avg', '${_dataService.weeklyAvgUsage.toStringAsFixed(1)}h', Icons.timer)), const SizedBox(width: 12), Expanded(child: _benchmarkCard('Avg Guilt', '${_dataService.weeklyAvgGuilt.round()}', Icons.psychology))]),
        ],
      ),
    );
  }

  Widget _benchmarkCard(String label, String val, IconData icon) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.cardBlue, borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(icon, color: AppTheme.cyan, size: 20), const SizedBox(height: 8), Text(val, style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))]));
  }

  Widget _buildSlider5DetailedTrends() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Trends', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(LineChartData(
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (s) => AppTheme.cardBlue)),
              titlesData: FlTitlesData(show: true, leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text('D${v.toInt() + 1}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))))),
              gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: _dataService.weeklyUsageHours.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(), isCurved: true, color: AppTheme.cyan, barWidth: 4, dotData: const FlDotData(show: false)),
                LineChartBarData(spots: _dataService.weeklyGuiltIndices.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value / 10)).toList(), isCurved: true, color: Colors.redAccent, barWidth: 2, dashArray: [5, 5]),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider6AppsToday() {
    final sortedApps = _dataService.topAppUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily App Audit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          const Text('Every footprint left today.', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: sortedApps.length,
              itemBuilder: (context, index) {
                final app = sortedApps[index];
                final isTop5 = index < 5;
                final h = (app.value / 60).toInt();
                final m = (app.value % 60).toInt();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isTop5 ? AppTheme.cyan.withOpacity(0.3) : Colors.white10),
                    boxShadow: isTop5 ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.1), blurRadius: 8)] : [],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: Colors.white.withOpacity(0.05), child: Icon(Icons.android, color: isTop5 ? AppTheme.cyan : AppTheme.textMuted, size: 20)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.key.split('.').last.toUpperCase(), style: TextStyle(color: AppTheme.textLight, fontWeight: isTop5 ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                            if (isTop5) const Text('TOP HABIT', style: TextStyle(color: AppTheme.cyan, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ],
                        ),
                      ),
                      Text('${h}h ${m}m', style: TextStyle(color: isTop5 ? AppTheme.cyan : AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentPageIndex == i ? 16 : 8, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: _currentPageIndex == i ? AppTheme.cyan : Colors.white10))));
  }
}
