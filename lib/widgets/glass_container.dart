import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/performance/performance_mode.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.15,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.border,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final performanceMode = plantVersePerformanceMode(context);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? Colors.white).withOpacity(opacity)
            : null,
        gradient: gradient,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(28),
        border: border ??
            Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(28),
        child: performanceMode || blur <= 0
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: content,
              ),
      ),
    );
  }
}
