import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../dashboard/breathing_lotus.dart';

class AppBlockOverlay extends StatelessWidget {
  final String packageName;
  final VoidCallback onDismiss;

  const AppBlockOverlay({
    super.key,
    required this.packageName,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBlue,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BreathingLotus(size: 200, color: AppTheme.cyan),
            const SizedBox(height: 48),
            const Text(
              'PAUSE & BREATHE',
              style: TextStyle(
                color: AppTheme.cyan,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your 10 seconds of $packageName are up.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardBlue.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cyan.withOpacity(0.2)),
              ),
              child: const Column(
                children: [
                  Text(
                    '"The most important part of the journey is knowing when to stop and look within."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '- Luminance Zen',
                    style: TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 64),
            ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                elevation: 10,
                shadowColor: AppTheme.cyan.withOpacity(0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_outlined),
                  SizedBox(width: 12),
                  Text(
                    'RETURN TO HARMONY',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
