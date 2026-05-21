import 'package:flutter_test/flutter_test.dart';
import 'package:plantverse_ai/services/plant_identity_guard.dart';

void main() {
  test('keeps strong plant identity confirmed', () {
    final result = PlantIdentityGuard.normalize({
      'common_name': 'Snake Plant',
      'scientific_name': 'Dracaena trifasciata',
      'family': 'Asparagaceae',
      'confidence': 0.88,
      'recognition_mode': 'live_ai',
    });

    expect(result['common_name'], 'Snake Plant');
    expect(result['identity_status'], PlantIdentityGuard.confirmed);
    expect(result['requires_identity_confirmation'], isFalse);
    expect(result['candidate_matches'], isNotEmpty);
  });

  test('downgrades weak specific guesses to unconfirmed plant', () {
    final result = PlantIdentityGuard.normalize({
      'common_name': 'Coral Beads',
      'scientific_name': 'Nertera granadensis',
      'family': 'Rubiaceae',
      'confidence': 0.21,
      'recognition_mode': 'live_ai',
      'candidate_matches': [
        {
          'common_name': 'Miniature Pine Tree',
          'scientific_name': 'Crassula tetragona',
          'confidence': 0.37,
          'reason': 'Pine-like succulent stems',
        }
      ],
    });

    expect(result['common_name'], 'Unconfirmed plant');
    expect(result['scientific_name'], 'Species not confirmed');
    expect(result['original_common_name'], 'Coral Beads');
    expect(result['identity_status'], PlantIdentityGuard.unconfirmed);
    expect(result['requires_identity_confirmation'], isTrue);
    expect(
      (result['candidate_matches'] as List).first['scientific_name'],
      'Crassula tetragona',
    );
  });

  test('marks moderate guesses as needing confirmation', () {
    final result = PlantIdentityGuard.normalize({
      'common_name': 'Rubber Plant',
      'scientific_name': 'Ficus elastica',
      'family': 'Moraceae',
      'confidence': 0.48,
      'recognition_mode': 'groq_vision',
    });

    expect(result['common_name'], 'Rubber Plant');
    expect(result['identity_status'], PlantIdentityGuard.needsConfirmation);
    expect(result['requires_identity_confirmation'], isTrue);
  });

  test('normalizes percent confidence values', () {
    final result = PlantIdentityGuard.normalize({
      'common_name': 'Aloe Vera',
      'scientific_name': 'Aloe barbadensis miller',
      'confidence': 72,
      'recognition_mode': 'openrouter_vision',
    });

    expect(result['confidence'], closeTo(0.72, 0.001));
    expect(result['identity_status'], PlantIdentityGuard.likely);
  });
}
