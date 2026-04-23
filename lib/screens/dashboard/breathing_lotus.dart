import 'package:flutter/material.dart';
import 'dart:math' as math;

class BreathingLotus extends StatefulWidget {
  final double size;
  final Color? color;
  const BreathingLotus({super.key, this.size = 300, this.color});

  @override
  State<BreathingLotus> createState() => _BreathingLotusState();
}

class _BreathingLotusState extends State<BreathingLotus> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lotusColor = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: LotusPainter(color: lotusColor.withOpacity(0.3)),
          ),
        );
      },
    );
  }
}

class LotusPainter extends CustomPainter {
  final Color color;
  LotusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final petalWidth = size.width * 0.15;
    final petalHeight = size.height * 0.4;

    // Draw multiple layers of petals
    _drawPetalLayer(canvas, center, 8, petalWidth, petalHeight, paint, 0);
    _drawPetalLayer(canvas, center, 8, petalWidth * 0.8, petalHeight * 0.8, paint, math.pi / 8);
    _drawPetalLayer(canvas, center, 8, petalWidth * 0.6, petalHeight * 0.6, paint, 0);
    
    // Small center piece
    canvas.drawCircle(center, petalWidth * 0.4, Paint()..color = color.withOpacity(0.6));
  }

  void _drawPetalLayer(Canvas canvas, Offset center, int count, double w, double h, Paint paint, double startAngle) {
    for (int i = 0; i < count; i++) {
      final angle = startAngle + (i * 2 * math.pi / count);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      // Draw a petal (ellipse-like shape)
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(w, -h / 2, 0, -h)
        ..quadraticBezierTo(-w, -h / 2, 0, 0)
        ..close();
      
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
