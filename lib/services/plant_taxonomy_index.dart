import 'dart:convert';

import 'package:flutter/services.dart';

class PlantTaxonomyIndex {
  static const _assetPath = 'assets/data/plant_taxonomy_10000.json';
  static List<Map<String, dynamic>>? _records;

  static Future<Map<String, dynamic>?> matchByNameSignal(
      String fileName) async {
    final query = _normalize(fileName.replaceAll(RegExp(r'\.[^.]+$'), ' '));
    if (query.length < 4) return null;

    final records = await _loadRecords();
    for (final record in records) {
      if (_matches(record, query)) return record;
    }
    return null;
  }

  static Map<String, dynamic> taxonomyProfile(Map<String, dynamic> record) {
    final canonicalName = _string(record['canonicalName']);
    final scientificName = _string(record['scientificName'], canonicalName);
    final family = _string(record['family'], 'Plant family not listed');
    final genus = _string(record['genus'], 'Genus not listed');
    final order = _string(record['order'], 'Order not listed');
    final sourceUrl = _string(record['sourceUrl']);
    final gbifKey = _string(record['gbifKey']);
    final description = _string(record['description']);
    final commonNames = record['commonNames'] is List
        ? (record['commonNames'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final displayName =
        commonNames.isNotEmpty ? commonNames.first : canonicalName;

    return {
      'common_name': displayName,
      'scientific_name': scientificName,
      'family': family,
      'confidence': 0.46,
      'recognition_mode': 'offline_taxonomy',
      'last_reference_reviewed': '2026-05-18',
      'reference_sources': [
        'GBIF Backbone Taxonomy species record: $sourceUrl',
        'GBIF Backbone Taxonomy dataset: https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c',
        'World Flora Online Plant List: https://wfoplantlist.org/',
        'Kew Plants of the World Online: https://powo.science.kew.org/',
      ],
      'description': description.isNotEmpty
          ? '$description Taxonomy match from the offline 10,000-plant PlantVerse index. Care and toxicity are not assumed unless a source-backed profile exists.'
          : 'Taxonomy match from the offline 10,000-plant PlantVerse index. Care and toxicity are not assumed unless a source-backed profile exists.',
      'care_difficulty': 'Not confirmed from taxonomy alone',
      'native_region': 'Distribution not packaged for this offline record',
      'toxicity_level': 'Not confirmed - keep away from pets and children',
      'toxicity_score': 0.45,
      'water_requirement': 'Species-specific watering not confirmed',
      'water_score': 0.50,
      'sunlight_requirement': 'Species-specific light needs not confirmed',
      'sunlight_score': 0.50,
      'temperature_range': 'Species-specific range not confirmed',
      'humidity_level': 'Species-specific humidity not confirmed',
      'humidity_score': 0.50,
      'photosynthesis_score': 0.50,
      'oxygen_output':
          'This is a taxonomy-only offline match. Oxygen output cannot be estimated responsibly without growth habit, leaf area, and light data.',
      'air_intake':
          'Carbon dioxide, light energy, and water when actively photosynthesizing.',
      'air_release': 'Oxygen and water vapor during active photosynthesis.',
      'health_summary':
          '$canonicalName is remembered in the offline taxonomy index as a species in $family, genus $genus, order $order. Detailed care/toxicity is intentionally conservative until a source-backed profile is added.',
      'story_markdown':
          '$canonicalName is part of the PlantVerse offline taxonomy memory, sourced from GBIF record $gbifKey. The app can remember its scientific identity and classification offline, while detailed care, toxicity, and environmental estimates stay conservative until verified references are packaged.',
      'human_toxicity': {
        'level': 'Not confirmed',
        'severity_score': 0.45,
        'touch_effects':
            'Do not assume skin safety from taxonomy alone. Avoid sap contact until a reliable source confirms safety.',
        'ingestion_effects':
            'Do not ingest plant material. Contact poison control if symptoms occur.',
        'skin_irritation':
            'Unknown; some species irritate skin through sap, oils, spines, hairs, or latex.',
        'child_warning':
            'Keep away from children until a species-specific toxicity source is added.',
        'first_aid':
            'Rinse exposed skin or mouth with water and seek qualified help if symptoms appear.'
      },
      'pet_toxicity': {
        'cats': {
          'severity': 'Not confirmed',
          'symptoms': 'Watch for drooling, vomiting, diarrhea, or lethargy.',
          'emergency_level': 'Avoid exposure'
        },
        'dogs': {
          'severity': 'Not confirmed',
          'symptoms':
              'Watch for mouth irritation, vomiting, diarrhea, or lethargy.',
          'emergency_level': 'Avoid exposure'
        },
        'birds': {
          'severity': 'Not confirmed',
          'symptoms': 'Birds can be sensitive to plant chemicals.',
          'emergency_level': 'Avoid exposure'
        }
      },
      'toxic_compounds': {
        'summary':
            'Not confirmed for this species in the packaged offline care database.',
        'harmful_compounds': 'Not confirmed',
        'alkaloids': 'Not confirmed',
        'oxalates': 'Not confirmed',
        'latex': 'Not confirmed',
        'sap_chemicals': 'Not confirmed'
      },
      'care_intelligence': {
        'water': {
          'score': 0.50,
          'ideal_frequency': 'Not confirmed for this species.',
          'amount_estimation': 'Check soil moisture and avoid standing water.',
          'overwatering_risk': 'Possible for many potted plants.',
          'underwatering_symptoms':
              'Wilting, crisping, leaf drop, or slow growth.',
          'seasonal_changes': 'Adjust only after species care is confirmed.',
          'soil_moisture_preference': 'Not confirmed.'
        },
        'sunlight': {
          'score': 0.50,
          'direct_tolerance': 'Not confirmed.',
          'indirect_preference':
              'Bright indirect light is a cautious default for many houseplants.',
          'indoor_compatibility': 'Not confirmed from taxonomy alone.',
          'outdoor_compatibility': 'Not confirmed from taxonomy alone.',
          'best_window_direction': 'Not confirmed.',
          'heat_tolerance': 'Not confirmed.'
        },
        'humidity': {
          'score': 0.50,
          'ideal_humidity': 'Not confirmed.',
          'dry_climate_tolerance': 'Not confirmed.',
          'misting_recommendations':
              'Do not mist unless species care confirms it.',
          'ac_room_compatibility':
              'Avoid harsh drafts until care needs are known.'
        },
        'temperature': {
          'score': 0.50,
          'minimum_temperature': 'Not confirmed.',
          'maximum_temperature': 'Not confirmed.',
          'best_growth_temperature': 'Not confirmed.',
          'winter_survival': 'Not confirmed.'
        }
      },
      'environmental_intelligence': {
        'oxygen': {
          'score': 0.50,
          'estimated_daily_release': 'Not estimated for taxonomy-only records.',
          'day_vs_night':
              'Most plants release oxygen during daylight photosynthesis and respire day and night.',
          'air_purification_score': 0.35,
          'indoor_contribution': 'Not confirmed.',
          'nasa_clean_air_relevance': 'Not confirmed.',
          'photosynthesis_efficiency': 'Not confirmed.',
          'approximation_logic':
              'No species-specific biology estimate is generated without verified care/biology sources.'
        },
        'co2': {
          'score': 0.50,
          'estimated_daily_absorption':
              'Not estimated for taxonomy-only records.',
          'photosynthesis_cycle':
              'CO2 uptake depends on species, light, water, leaf area, and health.',
          'carbon_capture_efficiency': 'Not confirmed.',
          'indoor_air_improvement': 'Not confirmed.'
        },
        'biology': {
          'photosynthesis_type': 'Not confirmed',
          'transpiration_details': 'Not confirmed.',
          'root_oxygen_exchange':
              'Most roots require oxygenated substrate; exact needs vary by species.',
          'growth_respiration_details':
              'Plants respire to power maintenance and growth.'
        }
      }
    };
  }

  static Future<List<Map<String, dynamic>>> _loadRecords() async {
    final cached = _records;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final records = (decoded['records'] as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
    _records = records;
    return records;
  }

  static bool _matches(Map<String, dynamic> record, String query) {
    final names = <String>[
      _string(record['canonicalName']),
      _string(record['scientificName']),
      ...record['commonNames'] is List
          ? (record['commonNames'] as List).map((item) => item.toString())
          : const <String>[],
    ];

    for (final name in names) {
      final normalized = _normalize(name);
      if (normalized.length < 4) continue;
      if (normalized.contains(' ') && query.contains(normalized)) return true;
      if (query == normalized) return true;
      if (query.replaceAll(' ', '').contains(normalized.replaceAll(' ', ''))) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _string(Object? value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
