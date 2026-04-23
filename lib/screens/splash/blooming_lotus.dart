import 'package:flutter/material.dart';
import 'dart:math' as math;

class BloomingLotus extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const BloomingLotus({
    Key? key,
    this.size = 150,
    this.color = Colors.cyan,
    this.duration = const Duration(seconds: 4), // Breathing pace
  }) : super(key: key);

  @override
  State<BloomingLotus> createState() => _BloomingLotusState();
}

class _BloomingLotusState extends State<BloomingLotus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bloomAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Natural breathing motion
    _bloomAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bloomAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RadialGlowingLotusPainter(
            progress: _bloomAnimation.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _RadialGlowingLotusPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadialGlowingLotusPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    int numPetals = 8;
    
    for (int i = 0; i < numPetals; i++) {
        // Fixed angle, NO ROTATION over time so it doesn't look like a gear
        double angle = (2 * math.pi / numPetals) * i;

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);

        // Petals extend outward
        double distance = maxRadius * 0.15 + (maxRadius * 0.40 * progress);
        
        // Petal dimensions
        double petalLength = maxRadius * 0.4 * (0.8 + 0.4 * progress);
        double petalWidth = maxRadius * 0.25 * (0.8 + 0.4 * progress);

        // Outer Glow
        final Paint outerGlow = Paint()
          ..color = color.withValues(alpha: 0.15 + 0.2 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
          
        Rect outerRect = Rect.fromCenter(center: Offset(0, distance), width: petalWidth * 2.0, height: petalLength * 2.0);
        canvas.drawOval(outerRect, outerGlow);

        // Main Visible Petal (More opaque now)
        final Paint mainPetal = Paint()
          ..color = color.withValues(alpha: 0.5 + 0.3 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          
        Rect mainRect = Rect.fromCenter(center: Offset(0, distance), width: petalWidth, height: petalLength);
        canvas.drawOval(mainRect, mainPetal);
        
        // Bright Inner Core (Even brighter)
        final Paint innerCore = Paint()
          ..color = Colors.white.withValues(alpha: 0.3 + 0.4 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          
        Rect innerRect = Rect.fromCenter(center: Offset(0, distance), width: petalWidth * 0.3, height: petalLength * 0.6);
        canvas.drawOval(innerRect, innerCore);

        canvas.restore();
    }
    
    // Central pulsating glow
    final Paint centerGlow = Paint()
      ..color = color.withValues(alpha: 0.4 + 0.3 * progress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, maxRadius * 0.15 + (maxRadius * 0.15 * progress), centerGlow);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowingLotusPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
