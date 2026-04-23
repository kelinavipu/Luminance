import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BreathingBlockScreen extends StatelessWidget {
  final VoidCallback onReturnCallback;

  const BreathingBlockScreen({
    super.key,
    required this.onReturnCallback,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Lotus Icon
              Image.asset(
                'assets/lotus.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.spa, size: 120, color: Colors.pinkAccent),
              ),
              const Spacer(flex: 1),
              // Title
              const Text(
                'Breathe.',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 48,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Subtitle
              const Text(
                'This app has been gently restricted to\nprotect your wellbeing.\n\nTake a mindful pause.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 1),
              // Quote
              const Text(
                '"Almost everything will work again\nif you unplug it for a few minutes.\n— Anne Lamott"',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onReturnCallback,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Return to Peace',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
