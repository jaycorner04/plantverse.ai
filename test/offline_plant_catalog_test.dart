import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantverse_ai/services/offline_plant_catalog.dart';

void main() {
  test('pine succulent signal resolves to Crassula tetragona profile', () {
    final profile = OfflinePlantCatalog.identify(
      imageBytes: Uint8List.fromList(const [1, 2, 3]),
      fileName: 'miniature-pine-succulent.jpg',
    );

    expect(profile['scientific_name'], 'Crassula tetragona');
    expect(profile['common_name'], contains('Pine'));
    expect(profile['family'], 'Crassulaceae');
  });
}
