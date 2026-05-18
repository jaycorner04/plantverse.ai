import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'offline_plant_catalog.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

class AiServiceException implements Exception {
  final String message;

  const AiServiceException(this.message);

  @override
  String toString() => message;
}

class AiQuotaLimitException extends AiServiceException {
  const AiQuotaLimitException(super.message);
}

class AiService {
  Map<String, String> get _env => dotenv.isInitialized ? dotenv.env : const {};
  String get _apiKey => _env['GEMINI_API_KEY']?.trim() ?? '';
  String get _model => _env['GEMINI_MODEL']?.trim().isNotEmpty == true
      ? _env['GEMINI_MODEL']!.trim()
      : 'gemini-2.0-flash-lite';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<Map<String, dynamic>> identifyPlant({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (!isConfigured) {
      return _offlineCatalogProfile(imageBytes: imageBytes, fileName: fileName);
    }

    try {
      final text = await _generate(
        prompt: '''
Identify the plant in this image. Return only valid JSON with:
common_name, scientific_name, family, confidence, description, care_difficulty,
native_region, toxicity_level, toxicity_score, water_requirement, water_score,
sunlight_requirement, sunlight_score, temperature_range, humidity_level,
humidity_score, photosynthesis_score, oxygen_output, air_intake, air_release,
health_summary, story_markdown,
human_toxicity, pet_toxicity, toxic_compounds, care_intelligence,
environmental_intelligence.
If the image is not a plant, set common_name to "Unknown" and explain why in description.
Use confidence, toxicity_score, water_score, sunlight_score, humidity_score, and photosynthesis_score from 0 to 1.
toxicity_score should be higher when the plant is more toxic to pets or people.
water_score should be higher when the plant needs more frequent watering.
sunlight_score should be higher when the plant needs more intense/direct light.
humidity_score should be higher when the plant prefers more humidity.
photosynthesis_score should estimate active photosynthesis potential from visible leaf health and light preference.
oxygen_output should be a short plain-language estimate of oxygen production, noting it varies with plant size, light, and health.
air_intake should list what the plant takes from air/environment, such as carbon dioxide, light energy, and water.
air_release should list what the plant releases into the air, such as oxygen and water vapor.
story_markdown should be a short, vivid 120-180 word story about origin, habitat, and care personality.

human_toxicity must be an object with:
level, severity_score, touch_effects, ingestion_effects, skin_irritation,
child_warning, first_aid.

pet_toxicity must be an object with cats, dogs, and birds. Each pet object must
include severity, symptoms, emergency_level.

toxic_compounds must be an object with:
summary, harmful_compounds, alkaloids, oxalates, latex, sap_chemicals.
Use realistic plant chemistry, and say "not commonly reported" when uncertain.

care_intelligence must be an object with:
water: {score, ideal_frequency, amount_estimation, overwatering_risk,
underwatering_symptoms, seasonal_changes, soil_moisture_preference},
sunlight: {score, direct_tolerance, indirect_preference, indoor_compatibility,
outdoor_compatibility, best_window_direction, heat_tolerance},
humidity: {score, ideal_humidity, dry_climate_tolerance,
misting_recommendations, ac_room_compatibility},
temperature: {score, minimum_temperature, maximum_temperature,
best_growth_temperature, winter_survival}.

environmental_intelligence must be an object with:
oxygen: {score, estimated_daily_release, day_vs_night, air_purification_score,
indoor_contribution, nasa_clean_air_relevance, photosynthesis_efficiency,
approximation_logic},
co2: {score, estimated_daily_absorption, photosynthesis_cycle,
carbon_capture_efficiency, indoor_air_improvement},
biology: {photosynthesis_type, transpiration_details, root_oxygen_exchange,
growth_respiration_details}.

All estimates must be scientifically styled, realistic, and human readable.
When exact values are unavailable, provide estimated ranges and explain the
approximation logic. Do not diagnose serious human or animal medical issues;
use first aid and vet/poison-control guidance for safety only.
''',
        imageBytes: imageBytes,
        fileName: fileName,
      );

      return _decodeObject(text);
    } on AiServiceException {
      return _offlineCatalogProfile(imageBytes: imageBytes, fileName: fileName);
    } catch (_) {
      return _offlineCatalogProfile(imageBytes: imageBytes, fileName: fileName);
    }
  }

  Future<Map<String, dynamic>> diagnoseDisease({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (!isConfigured) {
      return _offlineDiagnosis(imageBytes: imageBytes, fileName: fileName);
    }

    try {
      final text = await _generate(
        prompt: '''
Act as a plant care assistant. Analyze visible plant health symptoms in this image.
Return only valid JSON with:
diagnosis, confidence, severity, treatment, recovery_time, prevention, steps.
steps must be an array of 3 to 5 short actionable strings.
If the photo is unclear, say so and recommend retaking the image.
Use confidence from 0 to 1.
''',
        imageBytes: imageBytes,
        fileName: fileName,
      );

      return _decodeObject(text);
    } on AiServiceException {
      return _offlineDiagnosis(imageBytes: imageBytes, fileName: fileName);
    } catch (_) {
      return _offlineDiagnosis(imageBytes: imageBytes, fileName: fileName);
    }
  }

  Future<String> _generate({
    required String prompt,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    _ensureConfigured();

    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];

    if (imageBytes != null && fileName != null) {
      parts.add({
        'inline_data': {
          'mime_type': _mimeType(fileName),
          'data': base64Encode(imageBytes),
        },
      });
    }

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'generationConfig': {
        'temperature': 0.25,
      },
    };

    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _geminiError(response);
      if (_isQuotaLimit(response.statusCode, message)) {
        throw AiQuotaLimitException(message);
      }
      throw AiServiceException(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final output = _extractOutputText(data).trim();
    if (output.isEmpty) {
      throw const AiServiceException('Gemini returned an empty answer.');
    }
    return output;
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const AiServiceException(
        'Add your free GEMINI_API_KEY in the .env file, then rebuild/restart the app.',
      );
    }
  }

  Map<String, dynamic> _decodeObject(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw AiServiceException('The AI response was not valid JSON: $text');
    }

    return jsonDecode(cleaned.substring(start, end + 1))
        as Map<String, dynamic>;
  }

  String _extractOutputText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';

    final first = candidates.first;
    if (first is! Map<String, dynamic>) return '';

    final content = first['content'];
    if (content is! Map<String, dynamic>) return '';

    final parts = content['parts'];
    if (parts is! List) return '';

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] is String) {
        buffer.write(part['text']);
      }
    }
    return buffer.toString();
  }

  String _geminiError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {
      // Fall back to the generic status message below.
    }
    return 'Gemini request failed with status ${response.statusCode}.';
  }

  bool _isQuotaLimit(int statusCode, String message) {
    final lower = message.toLowerCase();
    return statusCode == 429 ||
        lower.contains('resource_exhausted') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('too many requests');
  }

  Map<String, dynamic> _offlineCatalogProfile({
    required Uint8List imageBytes,
    required String fileName,
  }) {
    try {
      return OfflinePlantCatalog.identify(
        imageBytes: imageBytes,
        fileName: fileName,
      );
    } catch (_) {
      return _offlinePlantProfile();
    }
  }

  Map<String, dynamic> _offlinePlantProfile() {
    return {
      'common_name': 'Plant scan saved',
      'scientific_name': 'AI limit reached',
      'family': 'Offline estimate',
      'confidence': 0.48,
      'description':
          'PlantVerse Free Mode is active, so this scan uses an offline care profile instead of paid cloud AI. Add your own Gemini key later only if you want exact species recognition.',
      'care_difficulty': 'Moderate until identified',
      'native_region': 'Unknown in free offline mode',
      'toxicity_level': 'Unknown - keep away from pets and children',
      'toxicity_score': 0.45,
      'water_requirement': 'Check top soil before watering',
      'water_score': 0.52,
      'sunlight_requirement': 'Bright indirect light is safest',
      'sunlight_score': 0.62,
      'temperature_range': '18-30 C',
      'humidity_level': 'Average indoor humidity',
      'humidity_score': 0.50,
      'photosynthesis_score': 0.56,
      'oxygen_output':
          'Offline estimate: a small indoor plant may release a modest amount of oxygen during bright daylight, but exact output depends on species, leaf area, light, and health.',
      'air_intake': 'Carbon dioxide, light energy, and water.',
      'air_release': 'Oxygen and water vapor during daylight photosynthesis.',
      'health_summary':
          'Free offline mode is active. The photo is saved, and PlantVerse is showing safe general plant-care intelligence without using paid cloud AI.',
      'story_markdown':
          'Your plant is running in Free Mode. Treat it gently: bright indirect light, careful watering only when the top soil dries, and no pet or child access until exact toxicity is confirmed.',
      'human_toxicity': {
        'level': 'Unknown',
        'severity_score': 0.45,
        'touch_effects':
            'Avoid sap contact until the species is confirmed. Wash hands after handling.',
        'ingestion_effects':
            'Do not ingest unidentified plant material. Contact poison control if symptoms appear.',
        'skin_irritation': 'Sensitive skin may react to sap or leaf residue.',
        'child_warning':
            'Keep the plant out of reach of children until identification is confirmed.',
        'first_aid':
            'Rinse mouth or skin, remove plant residue, and seek qualified help if symptoms occur.'
      },
      'pet_toxicity': {
        'cats': {
          'severity': 'Unknown',
          'symptoms':
              'Watch for drooling, vomiting, lethargy, or appetite loss.',
          'emergency_level': 'Monitor closely'
        },
        'dogs': {
          'severity': 'Unknown',
          'symptoms':
              'Watch for mouth irritation, vomiting, diarrhea, or lethargy.',
          'emergency_level': 'Monitor closely'
        },
        'birds': {
          'severity': 'Unknown',
          'symptoms':
              'Birds can be sensitive to plant chemicals; avoid cage access.',
          'emergency_level': 'Avoid exposure'
        }
      },
      'toxic_compounds': {
        'summary':
            'Unknown until species identification is available. Treat as potentially irritating.',
        'harmful_compounds': 'Not confirmed',
        'alkaloids': 'Not confirmed',
        'oxalates': 'Not confirmed',
        'latex': 'Not confirmed',
        'sap_chemicals': 'Not confirmed'
      },
      'care_intelligence': {
        'water': {
          'score': 0.52,
          'ideal_frequency': 'Water only when the top soil begins to dry.',
          'amount_estimation': 'Moisten evenly, then drain excess water.',
          'overwatering_risk': 'High if soil stays wet for many days.',
          'underwatering_symptoms': 'Wilting, curling, dry edges, slow growth.',
          'seasonal_changes': 'Water less in cool or low-light months.',
          'soil_moisture_preference': 'Slightly dry top layer before watering.'
        },
        'sunlight': {
          'score': 0.62,
          'direct_tolerance':
              'Avoid harsh afternoon sun until species is known.',
          'indirect_preference': 'Bright indirect light is safest.',
          'indoor_compatibility': 'Likely suitable near a bright window.',
          'outdoor_compatibility': 'Move outdoors gradually if needed.',
          'best_window_direction': 'East or filtered south/west light.',
          'heat_tolerance': 'Avoid heat stress above normal indoor conditions.'
        },
        'humidity': {
          'score': 0.50,
          'ideal_humidity': 'Average indoor humidity.',
          'dry_climate_tolerance': 'Monitor for crisp leaf edges.',
          'misting_recommendations':
              'Avoid heavy misting unless species needs it.',
          'ac_room_compatibility': 'Keep away from strong AC drafts.'
        },
        'temperature': {
          'score': 0.60,
          'minimum_temperature': 'Keep above 15 C.',
          'maximum_temperature': 'Avoid sustained heat above 32 C.',
          'best_growth_temperature': '18-30 C.',
          'winter_survival': 'Protect from cold windows and drafts.'
        }
      },
      'environmental_intelligence': {
        'oxygen': {
          'score': 0.56,
          'estimated_daily_release':
              'Small indoor oxygen contribution during bright daylight; exact liters vary by species and leaf area.',
          'day_vs_night':
              'Oxygen release rises in daylight and drops at night while respiration continues.',
          'air_purification_score': 0.38,
          'indoor_contribution':
              'Best seen as a small wellness contribution, not a room-scale oxygen source.',
          'nasa_clean_air_relevance':
              'Clean-air relevance cannot be confirmed until species is identified.',
          'photosynthesis_efficiency':
              'Moderate estimate in bright indirect light.',
          'approximation_logic':
              'Based on generic indoor plant behavior because Free Mode avoids paid cloud AI calls.'
        },
        'co2': {
          'score': 0.54,
          'estimated_daily_absorption':
              'Small carbon dioxide uptake during active daylight photosynthesis.',
          'photosynthesis_cycle':
              'CO2 is absorbed through stomata when light and water are available.',
          'carbon_capture_efficiency': 'Modest indoors.',
          'indoor_air_improvement':
              'Helpful as part of a planted space, but ventilation matters more.'
        },
        'biology': {
          'photosynthesis_type': 'Unknown until identification',
          'transpiration_details':
              'Leaves may release water vapor depending on humidity and light.',
          'root_oxygen_exchange':
              'Roots need oxygen pockets; saturated soil can suffocate tissue.',
          'growth_respiration_details':
              'Plants respire day and night for growth and repair.'
        }
      }
    };
  }

  Map<String, dynamic> _offlineDiagnosis({
    required Uint8List imageBytes,
    required String fileName,
  }) {
    var plantName = 'your plant';
    try {
      final plant = OfflinePlantCatalog.identify(
        imageBytes: imageBytes,
        fileName: fileName,
      );
      plantName = plant['common_name']?.toString() ?? plantName;
    } catch (_) {
      // Keep the generic label if the offline catalog cannot match.
    }

    return {
      'diagnosis': 'Offline health review for $plantName',
      'confidence': 0.42,
      'severity': 'Unknown in free offline mode',
      'treatment':
          'PlantVerse Free Mode is active. For $plantName, isolate the plant, remove badly damaged leaves with clean tools, check for pests under leaves, and avoid overwatering.',
      'recovery_time':
          'Add your own Gemini key later if you want a photo-specific cloud AI estimate.',
      'prevention':
          'Use bright indirect light, good airflow, clean pruning tools, and water only after checking soil moisture.',
      'steps': [
        'Move the plant to bright indirect light.',
        'Check soil moisture before watering.',
        'Inspect leaf undersides for pests or spots.',
        'Remove dead or infected leaves with clean scissors.',
        'Use an optional Gemini key later for exact photo-specific diagnosis.'
      ],
    };
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
