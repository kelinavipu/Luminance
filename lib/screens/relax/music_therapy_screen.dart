import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/app_theme.dart';
import '../splash/blooming_lotus.dart';

class MusicTherapyScreen extends StatefulWidget {
  const MusicTherapyScreen({super.key});

  @override
  State<MusicTherapyScreen> createState() => _MusicTherapyScreenState();
}

class _MusicTherapyScreenState extends State<MusicTherapyScreen> {
  late AudioPlayer _audioPlayer;
  double _sessionDurationMinutes = 15.0;
  String _selectedFrequency = "432 Hz";
  
  final Map<String, String> _trackPaths = {
    '432 Hz': '432hz.mp3',
    '852 Hz': '852hz.mp3',
    '285 Hz': '285hz.mp3',
  };

  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (_isPlaying) {
        _playSelectedTrack(); // Loop manually for seamless experience
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleSession() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _playSelectedTrack();
    }
  }

  Future<void> _playSelectedTrack() async {
    final fileName = _trackPaths[_selectedFrequency];
    if (fileName != null) {
      await _audioPlayer.play(AssetSource(fileName));
    }
  }

  void _showCustomDurationDialog() {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBlue,
          title: const Text('Custom Duration', style: TextStyle(color: AppTheme.textLight)),
          content: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.cyan),
            decoration: const InputDecoration(
              labelText: 'Enter minutes',
              labelStyle: TextStyle(color: AppTheme.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textMuted)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.cyan)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyan),
              onPressed: () {
                final int? val = int.tryParse(_controller.text);
                if (val != null && val > 0) {
                  setState(() => _sessionDurationMinutes = val.toDouble());
                  Navigator.pop(context);
                }
              },
              child: const Text('Set', style: TextStyle(color: AppTheme.darkBlue)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Therapy')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: _isPlaying 
                  ? const BloomingLotus(
                      size: 220,
                      color: AppTheme.cyan,
                      duration: Duration(seconds: 6),
                    )
                  : const Icon(Icons.headphones_rounded, size: 100, color: AppTheme.cyan),
              ),
            ),
            const SizedBox(height: 48),
            
            if (!_isPlaying) ...[
              const Text(
                'Solfeggio Frequency',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 16, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: _trackPaths.keys.map((freq) {
                  final isSelected = freq == _selectedFrequency;
                  return ChoiceChip(
                    label: Text(freq),
                    selected: isSelected,
                    selectedColor: AppTheme.cyan,
                    onSelected: (val) => setState(() => _selectedFrequency = freq),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.darkBlue : AppTheme.textLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppTheme.cardBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              
              const Text(
                'Session Duration',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 16, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _sessionDurationMinutes <= 60 ? _sessionDurationMinutes : 60,
                min: 0,
                max: 60,
                divisions: 60,
                activeColor: AppTheme.cyan,
                inactiveColor: AppTheme.cardBlue,
                label: '${_sessionDurationMinutes.toInt()} min',
                onChanged: (val) => setState(() => _sessionDurationMinutes = val),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0m', style: TextStyle(color: AppTheme.textMuted)),
                  Text('${_sessionDurationMinutes.toInt()} mins', style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
                  Text('60m', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
              Center(
                child: TextButton(
                  onPressed: _showCustomDurationDialog,
                  child: const Text('Custom Duration', style: TextStyle(color: AppTheme.textMuted, decoration: TextDecoration.underline)),
                ),
              ),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Resonating at',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Solfeggio Harmony',
                      style: TextStyle(color: AppTheme.cyan, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ],
            
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleSession,
                icon: Icon(_isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 32),
                label: Text(_isPlaying ? 'End Harmony' : 'Begin Therapy', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying ? AppTheme.cardBlue : AppTheme.cyan,
                  foregroundColor: _isPlaying ? AppTheme.cyan : AppTheme.darkBlue,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
