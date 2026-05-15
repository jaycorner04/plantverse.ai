import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredReveal extends StatelessWidget {
  final List<Widget> children;
  final Duration delay;
  final double initialSlide;
  final CrossAxisAlignment crossAxisAlignment;

  const StaggeredReveal({
    super.key,
    required this.children,
    this.delay = const Duration(milliseconds: 100),
    this.initialSlide = 0.2,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children:
          children.animate(interval: delay).fadeIn(duration: 500.ms).slideY(
                begin: initialSlide,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOutQuart,
              ),
    );
  }
}
