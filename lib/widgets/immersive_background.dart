import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class ImmersiveBackground extends StatelessWidget {
  final Widget child;

  const ImmersiveBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.canvasDark,
                  AppColors.canvasDeep,
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: -130,
          left: -120,
          child: _GlowOrb(
            size: 320,
            color: AppColors.emeraldGreen,
            opacity: 0.16,
          ),
        ),
        const Positioned(
          top: 160,
          right: -150,
          child: _GlowOrb(
            size: 330,
            color: AppColors.aiGlow,
            opacity: 0.11,
          ),
        ),
        const Positioned(
          bottom: -170,
          left: 40,
          child: _GlowOrb(
            size: 300,
            color: AppColors.forestGreen,
            opacity: 0.10,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ParticlePainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.aiGlow.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final points = <Offset>[
      Offset(size.width * 0.16, size.height * 0.14),
      Offset(size.width * 0.77, size.height * 0.12),
      Offset(size.width * 0.88, size.height * 0.34),
      Offset(size.width * 0.28, size.height * 0.48),
      Offset(size.width * 0.12, size.height * 0.74),
      Offset(size.width * 0.72, size.height * 0.82),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
