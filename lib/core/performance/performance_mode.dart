import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool plantVersePerformanceMode(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media == null) return kIsWeb;
  if (media.disableAnimations) return true;

  final shortestSide = media.size.shortestSide;
  return kIsWeb && shortestSide > 0 && shortestSide < 720;
}

