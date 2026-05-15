import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService();
});

class AiServiceException implements Exception {
  final String message;

  const AiServiceException(this.message);

  @override
  String toString() => message;
}

class AiService {
  String get _apiKey => dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  String get _model => dotenv.env['GEMINI_MODEL']?.trim().isNotEmpty == true
      ? dotenv.env['GEMINI_MODEL']!.trim()
      : 'gemini-2.5-flash';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<Map<String, dynamic>> identifyPlant({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
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
  }

  Future<Map<String, dynamic>> diagnoseDisease({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
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
  }

  Future<String> askBot(List<Map<String, String>> conversation) {
    final transcript = conversation
        .map((message) => '${message['role']}: ${message['content']}')
        .join('\n');

    return _generate(
      prompt: '''
You are PlantVerse AI, a careful botanical assistant. Give practical plant-care answers, ask for a photo when diagnosis is uncertain, and keep advice concise. Warn that severe toxicity or pesticide exposure needs a qualified professional.

Conversation:
$transcript
''',
    );
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
      throw AiServiceException(_geminiError(response));
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

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
