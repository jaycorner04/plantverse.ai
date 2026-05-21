class PlantIdentityGuard {
  static const confirmed = 'confirmed';
  static const likely = 'likely';
  static const needsConfirmation = 'needs_confirmation';
  static const unconfirmed = 'unconfirmed';

  static Map<String, dynamic> normalize(Map<String, dynamic> profile) {
    final result = Map<String, dynamic>.from(profile);
    final mode = _text(result['recognition_mode']).toLowerCase();
    final originalCommon = _text(result['common_name']);
    final originalScientific = _text(result['scientific_name']);
    final originalFamily = _text(result['family']);
    final confidence = _score(result['confidence'], _defaultConfidence(mode));
    final candidates = _candidateMatches(
      result,
      originalCommon,
      originalScientific,
      confidence,
    );
    final unknownName = _isUnknownIdentity(originalCommon, originalScientific);
    final status = _statusFor(
      confidence: confidence,
      mode: mode,
      unknownName: unknownName,
      candidates: candidates,
    );

    result['confidence'] = confidence;
    result['candidate_matches'] = candidates;
    result['identity_status'] = status;
    result['identity_status_label'] = _labelFor(status, confidence);
    result['identity_warning'] = _warningFor(status, candidates);
    result['identity_confidence_reason'] = _reasonFor(status, mode, confidence);
    result['requires_identity_confirmation'] =
        status == needsConfirmation || status == unconfirmed;

    if (status == unconfirmed && mode != 'offline_general') {
      return {
        ...result,
        'original_common_name': originalCommon,
        'original_scientific_name': originalScientific,
        'original_family': originalFamily,
        ..._unconfirmedOverlay(candidates),
      };
    }

    return result;
  }

  static List<Map<String, dynamic>> _candidateMatches(
    Map<String, dynamic> profile,
    String commonName,
    String scientificName,
    double confidence,
  ) {
    final raw = profile['candidate_matches'] ??
        profile['possible_matches'] ??
        profile['alternatives'] ??
        profile['similar_species'];
    final candidates = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        final candidate = _candidateFrom(item);
        if (candidate != null) candidates.add(candidate);
      }
    }

    if (!_isUnknownIdentity(commonName, scientificName)) {
      candidates.insert(0, {
        'common_name': commonName.isNotEmpty ? commonName : scientificName,
        'scientific_name': scientificName,
        'confidence': confidence,
        'reason': 'Top scan interpretation',
      });
    }

    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final candidate in candidates) {
      final common = _text(candidate['common_name']);
      final scientific = _text(candidate['scientific_name']);
      final key = '${common.toLowerCase()}|${scientific.toLowerCase()}';
      if (key == '|' || seen.contains(key)) continue;
      seen.add(key);
      unique.add({
        'common_name': common,
        'scientific_name': scientific,
        'confidence': _score(candidate['confidence'], 0),
        'reason': _text(candidate['reason'], fallback: 'Visual similarity'),
      });
    }

    unique.sort((a, b) {
      final left = _score(a['confidence'], 0);
      final right = _score(b['confidence'], 0);
      return right.compareTo(left);
    });
    return unique.take(4).toList(growable: false);
  }

  static Map<String, dynamic>? _candidateFrom(Object? value) {
    if (value is Map) {
      final common = _text(
        value['common_name'] ?? value['commonName'] ?? value['name'],
      );
      final scientific = _text(
        value['scientific_name'] ??
            value['scientificName'] ??
            value['canonicalName'],
      );
      if (_isUnknownIdentity(common, scientific)) return null;
      return {
        'common_name': common.isNotEmpty ? common : scientific,
        'scientific_name': scientific,
        'confidence': _score(value['confidence'] ?? value['score'], 0),
        'reason': _text(value['reason'], fallback: 'Visual similarity'),
      };
    }

    final text = _text(value);
    if (text.isEmpty) return null;
    return {
      'common_name': text,
      'scientific_name': '',
      'confidence': 0,
      'reason': 'Possible visual alternative',
    };
  }

  static String _statusFor({
    required double confidence,
    required String mode,
    required bool unknownName,
    required List<Map<String, dynamic>> candidates,
  }) {
    if (mode == 'offline_general' || unknownName) return unconfirmed;
    if (mode == 'offline_taxonomy') return needsConfirmation;
    if (mode == 'offline_catalog') {
      return confidence >= 0.62 ? likely : needsConfirmation;
    }
    if (confidence >= 0.78) return confirmed;
    if (confidence >= 0.58) return likely;
    final topCandidateConfidence =
        candidates.isEmpty ? 0.0 : _score(candidates.first['confidence'], 0.0);
    if (confidence >= 0.40 || topCandidateConfidence >= 0.40) {
      return needsConfirmation;
    }
    return unconfirmed;
  }

  static Map<String, dynamic> _unconfirmedOverlay(
    List<Map<String, dynamic>> candidates,
  ) {
    final possible = candidates.isEmpty
        ? ''
        : ' Possible match: ${_text(candidates.first['common_name'])}.';
    return {
      'common_name': 'Unconfirmed plant',
      'scientific_name': 'Species not confirmed',
      'family': 'Family not confirmed',
      'description':
          'The scan looks plant-like, but the identity confidence is too low to attach species-specific facts safely.$possible Retake with clear leaves, stems, and full plant shape.',
      'care_difficulty': 'Moderate until identified',
      'native_region': 'Unknown until identity is confirmed',
      'toxicity_level': 'Unknown - keep away from pets and children',
      'toxicity_score': 0.45,
      'water_requirement': 'Check soil moisture before watering',
      'water_score': 0.52,
      'sunlight_requirement': 'Bright indirect light is safest until confirmed',
      'sunlight_score': 0.62,
      'temperature_range': '18-30 C',
      'humidity_level': 'Average indoor humidity',
      'humidity_score': 0.50,
      'photosynthesis_score': 0.54,
      'health_summary':
          'PlantVerse is not confident enough to name this plant. To avoid wrong care or toxicity facts, it is showing conservative guidance and possible matches instead of pretending certainty.',
      'story_markdown':
          'This scan needs a clearer identity before PlantVerse can give species-specific care. Use a bright photo with several leaves, the stem structure, and the full plant silhouette.',
      'human_toxicity': {
        'level': 'Unknown',
        'severity_score': 0.45,
        'touch_effects': 'Avoid sap contact until the plant is confirmed.',
        'ingestion_effects':
            'Do not ingest unidentified plant material. Contact poison control if symptoms appear.',
        'skin_irritation': 'Sensitive skin may react to unknown sap or hairs.',
        'child_warning':
            'Keep away from children until identification is confirmed.',
        'first_aid':
            'Rinse exposed skin or mouth with water and seek qualified help if symptoms occur.',
      },
      'pet_toxicity': {
        'cats': {
          'severity': 'Unknown',
          'symptoms': 'Watch for drooling, vomiting, diarrhea, or lethargy.',
          'emergency_level': 'Avoid exposure',
        },
        'dogs': {
          'severity': 'Unknown',
          'symptoms': 'Watch for mouth irritation, vomiting, or lethargy.',
          'emergency_level': 'Avoid exposure',
        },
        'birds': {
          'severity': 'Unknown',
          'symptoms': 'Birds can be sensitive to plant chemicals.',
          'emergency_level': 'Avoid exposure',
        },
      },
      'toxic_compounds': {
        'summary': 'Not confirmed for this plant.',
        'harmful_compounds': 'Not confirmed',
        'alkaloids': 'Not confirmed',
        'oxalates': 'Not confirmed',
        'latex': 'Not confirmed',
        'sap_chemicals': 'Not confirmed',
      },
    };
  }

  static String _labelFor(String status, double confidence) {
    switch (status) {
      case confirmed:
        return '${(confidence * 100).toStringAsFixed(0)}% confirmed';
      case likely:
        return '${(confidence * 100).toStringAsFixed(0)}% likely match';
      case needsConfirmation:
        return 'Needs confirmation';
      default:
        return 'Unconfirmed plant';
    }
  }

  static String _warningFor(
    String status,
    List<Map<String, dynamic>> candidates,
  ) {
    switch (status) {
      case confirmed:
        return 'Strong identity signal from the scan.';
      case likely:
        return 'Likely match. Confirm leaf shape, stem structure, and growth habit before high-risk care or toxicity decisions.';
      case needsConfirmation:
        return 'The scan has a possible match, but PlantVerse is keeping the identity cautious. Compare the alternatives before trusting species-specific details.';
      default:
        if (candidates.isEmpty) {
          return 'Identity is too weak. Retake with clearer leaves, stems, and full plant shape.';
        }
        return 'Identity is too weak. Possible matches are shown only as leads, not confirmed facts.';
    }
  }

  static String _reasonFor(String status, String mode, double confidence) {
    final percent = '${(confidence * 100).toStringAsFixed(0)}%';
    if (mode == 'offline_taxonomy') {
      return 'Matched by name/taxonomy signal only, not direct visual proof.';
    }
    if (mode == 'offline_general') {
      return 'No reliable catalog or cloud identity was available.';
    }
    return 'Identity guard status: $status from $percent confidence using $mode.';
  }

  static bool _isUnknownIdentity(String commonName, String scientificName) {
    final joined = '$commonName $scientificName'.toLowerCase();
    if (joined.trim().isEmpty) return true;
    return joined.contains('unknown') ||
        joined.contains('unconfirmed') ||
        joined.contains('not confirmed') ||
        joined.contains('species pending');
  }

  static double _defaultConfidence(String mode) {
    if (mode == 'offline_general') return 0.28;
    if (mode == 'offline_taxonomy') return 0.46;
    if (mode == 'offline_catalog') return 0.68;
    return 0.50;
  }

  static double _score(Object? value, double fallback) {
    if (value is num) {
      final numeric = value.toDouble();
      return (numeric > 1 && numeric <= 100 ? numeric / 100 : numeric)
          .clamp(0, 1)
          .toDouble();
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) return fallback.clamp(0, 1).toDouble();
    return (parsed > 1 && parsed <= 100 ? parsed / 100 : parsed)
        .clamp(0, 1)
        .toDouble();
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
