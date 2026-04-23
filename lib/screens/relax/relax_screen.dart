import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'breathing_screen.dart';
import 'music_therapy_screen.dart';
import 'game_2048_screen.dart';

class RelaxScreen extends StatelessWidget {
  const RelaxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relax'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Unwind and Detach',
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a restorative activity to lower your stress and reduce phone dependence.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          _buildActivityCard(
            context,
            title: 'Breathing Exercises',
            subtitle: 'Blooming lotus focus routines',
            icon: Icons.spa,
            color: Colors.pinkAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BreathingScreen()),
            ),
          ),
          
          _buildActivityCard(
            context,
            title: 'Music Therapy',
            subtitle: 'Solfeggio frequencies & timed loops',
            icon: Icons.headphones,
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MusicTherapyScreen()),
            ),
          ),
          
          _buildActivityCard(
            context,
            title: '2048 Mini-Game',
            subtitle: 'A simple distraction-free puzzle',
            icon: Icons.grid_view_rounded,
            color: Colors.orangeAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Game2048Screen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardBlue,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
