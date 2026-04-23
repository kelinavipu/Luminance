import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPlaying = false;
  String _currentPhase = "Ready";
  
  String _selectedTechnique = "Box (4-4-4-4)";
  final List<String> _techniques = ["Default (4-2-4-2)", "Box (4-4-4-4)", "Relaxing (4-7-8)"];
  
  // Array of durations: [Inhale, Hold, Exhale, Hold]
  List<int> _currentTimings = [4, 4, 4, 4];
  int _totalDuration = 16;
  
  // Cutoffs
  late double _endInhale;
  late double _endHold1;
  late double _endExhale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _setTechnique(_selectedTechnique);
    
    _controller.addListener(() {
      if (!_isPlaying) return;

      double t = _controller.value;
      String newPhase = _currentPhase;
      
      if (t < _endInhale) {
        newPhase = "Breathe In";
      } else if (t < _endHold1) {
        newPhase = "Hold";
      } else if (t < _endExhale) {
        newPhase = "Breathe Out";
      } else {
        newPhase = "Hold";
      }

      if (newPhase != _currentPhase) {
        setState(() {
          _currentPhase = newPhase;
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isPlaying) {
        _controller.forward(from: 0.0);
      }
    });
  }
  
  void _setTechnique(String technique) {
    if (_isPlaying) return;
    setState(() {
      _selectedTechnique = technique;
      if (technique == "Default (4-2-4-2)") {
        _currentTimings = [4, 2, 4, 2];
      } else if (technique == "Box (4-4-4-4)") {
        _currentTimings = [4, 4, 4, 4];
      } else if (technique == "Relaxing (4-7-8)") {
        _currentTimings = [4, 7, 8, 0];
      }
      
      _totalDuration = _currentTimings.reduce((a, b) => a + b);
      _controller.duration = Duration(seconds: _totalDuration);
      
      _endInhale = _currentTimings[0] / _totalDuration;
      _endHold1 = (_currentTimings[0] + _currentTimings[1]) / _totalDuration;
      _endExhale = (_currentTimings[0] + _currentTimings[1] + _currentTimings[2]) / _totalDuration;
    });
  }

  void _toggleBreathing() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller.forward();
      } else {
        _currentPhase = "Ready";
        _controller.stop();
        _controller.reset();
      }
    });
  }

  double getScaleFromTime() {
    if (!_isPlaying) return 0.5; // Rest state
    double t = _controller.value;
    
    if (t < _endInhale) {
      // Inhale
      double normalizedT = t / _endInhale;
      return 0.5 + 0.5 * Curves.easeInOutSine.transform(normalizedT);
    } else if (t < _endHold1) {
      // Hold full
      return 1.0;
    } else if (t < _endExhale) {
      // Exhale
      double duration = _endExhale - _endHold1;
      double normalizedT = (t - _endHold1) / duration;
      return 1.0 - 0.5 * Curves.easeInOutSine.transform(normalizedT);
    } else {
      // Hold empty
      return 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Breathing Exercises')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isPlaying)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      'Select Technique',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _techniques.map((tech) {
                        final isSelected = tech == _selectedTechnique;
                        return ChoiceChip(
                          label: Text(tech),
                          selected: isSelected,
                          selectedColor: AppTheme.cyan,
                          onSelected: (val) => _setTechnique(tech),
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.darkBlue : AppTheme.textLight,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: AppTheme.cardBlue,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 128), // Spacer when playing so lotus stays centered
              
            const Spacer(),
            Text(
              _currentPhase,
              style: const TextStyle(
                color: AppTheme.cyan,
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 60),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final scale = getScaleFromTime();
                return AbstractLotus(scale: scale);
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _toggleBreathing,
              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(_isPlaying ? 'Stop Focus' : 'Start Focus'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPlaying ? AppTheme.cardBlue : AppTheme.cyan,
                foregroundColor: _isPlaying ? AppTheme.cyan : AppTheme.darkBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class AbstractLotus extends StatelessWidget {
  final double scale;
  
  const AbstractLotus({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final int numPetals = 6;
    final double maxExpanse = 60.0;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glowing limit circle
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.cyan.withOpacity(0.1),
              width: 2,
            ),
          ),
        ),
        
        // Petal generation
        for (int i = 0; i < numPetals; i++) 
          Transform.rotate(
            angle: (2 * math.pi / numPetals) * i + (scale * math.pi / 4), // Rotate slightly as it blooms
            child: Transform.translate(
              // Move petals out based on scale
              offset: Offset(0, -(maxExpanse * scale)),
              child: Container(
                width: 60,
                height: 120, // tall oval
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: AppTheme.cyan.withOpacity(0.3 * scale), // Brighter when expanded
                ),
              ),
            ),
          ),
          
        // Core center circle
        Container(
          width: 80 + (40 * scale),
          height: 80 + (40 * scale),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cyan.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: AppTheme.cyan.withOpacity(0.5 * scale),
                blurRadius: 30 * scale,
                spreadRadius: 10 * scale,
              )
            ],
          ),
        ),
      ],
    );
  }
}
