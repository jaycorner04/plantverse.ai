import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final scanResultProvider = StateProvider<ScanResult?>((ref) => null);

class ScanResult {
  final Map<String, dynamic> result;
  final Uint8List imageBytes;

  const ScanResult({
    required this.result,
    required this.imageBytes,
  });
}
