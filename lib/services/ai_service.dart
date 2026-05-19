import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'offline_plant_catalog.dart';
import 'plant_taxonomy_index.dart';

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
  static const _definedApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _definedModel = String.fromEnvironment('GEMINI_MODEL');
  static const _definedPlantNetKey = String.fromEnvironment('PLANTNET_API_KEY');
  static const _definedPlantIdKey = String.fromEnvironment('PLANT_ID_API_KEY');
  static const _definedPerenualKey = String.fromEnvironment('PERENUAL_API_KEY');
  static const _definedGroqKey = String.fromEnvironment('GROQ_API_KEY');
  static const _definedGroqModel = String.fromEnvironment('GROQ_VISION_MODEL');
  static const _definedOpenRouterKey =
      String.fromEnvironment('OPENROUTER_API_KEY');
  static const _definedBackendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL');
  static const _knownVisualConfusionGuidance = '''

Known visual confusion rule:
If the image shows an upright pine-like succulent with narrow pointed green
leaves arranged around branching woody or succulent stems, consider Crassula
tetragona, also called Miniature Pine Tree, Pine Tree Crassula, or pine
succulent. Do not label it as Coral Beads or Nertera granadensis unless the
image clearly shows a low creeping mat with many round orange-red bead-like
berries. Coral Beads is not a pine-like succulent.
''';

  Map<String, String> get _env => dotenv.isInitialized ? dotenv.env : const {};
  String _envValue(String key, String definedValue) {
    final runtimeValue = _env[key]?.trim() ?? '';
    return runtimeValue.isNotEmpty ? runtimeValue : definedValue.trim();
  }

  String get _apiKey => _envValue('GEMINI_API_KEY', _definedApiKey);
  String get _plantNetApiKey =>
      _envValue('PLANTNET_API_KEY', _definedPlantNetKey);
  String get _plantIdApiKey =>
      _envValue('PLANT_ID_API_KEY', _definedPlantIdKey);
  String get _perenualApiKey =>
      _envValue('PERENUAL_API_KEY', _definedPerenualKey);
  String get _groqApiKey => _envValue('GROQ_API_KEY', _definedGroqKey);
  String get _openRouterApiKey =>
      _envValue('OPENROUTER_API_KEY', _definedOpenRouterKey);
  String get _backendBaseUrl => _envValue(
        'BACKEND_BASE_URL',
        _definedBackendBaseUrl,
      ).replaceAll(RegExp(r'/+$'), '');
  String get _groqVisionModel {
    final model = _envValue('GROQ_VISION_MODEL', _definedGroqModel);
    return model.isNotEmpty
        ? model
        : 'meta-llama/llama-4-scout-17b-16e-instruct';
  }

  String get _model {
    final runtimeModel = _env['GEMINI_MODEL']?.trim() ?? '';
    if (runtimeModel.isNotEmpty) return runtimeModel;
    final definedModel = _definedModel.trim();
    return definedModel.isNotEmpty ? definedModel : 'gemini-2.0-flash-lite';
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  bool get hasLiveProvider =>
      _backendBaseUrl.isNotEmpty ||
      isConfigured ||
      _groqApiKey.isNotEmpty ||
      _openRouterApiKey.isNotEmpty ||
      _plantNetApiKey.isNotEmpty ||
      _plantIdApiKey.isNotEmpty;

  Future<Map<String, dynamic>> identifyPlant({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (_backendBaseUrl.isNotEmpty) {
      try {
        return await _identifyPlantWithBackend(
          imageBytes: imageBytes,
          fileName: fileName,
        );
      } on AiServiceException catch (error) {
        return _offlineCatalogProfile(
          imageBytes: imageBytes,
          fileName: fileName,
          fallbackReason: 'PlantVerse backend unavailable. ${error.message}',
        );
      }
    }

    if (_apiKey.isEmpty &&
        (_groqApiKey.isNotEmpty || _openRouterApiKey.isNotEmpty)) {
      final external = await _identifyWithExternalProviders(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: '',
      );
      if (external != null) return external;

      return _offlineCatalogProfile(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: 'No Gemini key is configured.',
      );
    }

    if (!isConfigured) {
      final external = await _identifyWithExternalProviders(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: 'No Gemini key is configured.',
      );
      if (external != null) return external;

      return _offlineCatalogProfile(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: 'No Gemini key is configured.',
      );
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
$_knownVisualConfusionGuidance
''',
        imageBytes: imageBytes,
        fileName: fileName,
      );

      final result = _decodeObject(text);
      result.putIfAbsent('recognition_mode', () => 'live_ai');
      return result;
    } on AiQuotaLimitException catch (error) {
      final reason = 'Gemini limit reached. ${error.message}';
      final external = await _identifyWithExternalProviders(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: reason,
      );
      if (external != null) return external;

      return _offlineCatalogProfile(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: reason,
      );
    }
  }

  Future<Map<String, dynamic>> diagnoseDisease({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (_backendBaseUrl.isNotEmpty) {
      try {
        return await _diagnoseDiseaseWithBackend(
          imageBytes: imageBytes,
          fileName: fileName,
        );
      } on AiServiceException catch (error) {
        return _offlineDiagnosis(
          imageBytes: imageBytes,
          fileName: fileName,
          fallbackReason: 'PlantVerse backend unavailable. ${error.message}',
        );
      }
    }

    if (!isConfigured) {
      return _offlineDiagnosis(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: 'No Gemini key is configured.',
      );
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
    } on AiQuotaLimitException catch (error) {
      return _offlineDiagnosis(
        imageBytes: imageBytes,
        fileName: fileName,
        fallbackReason: 'Gemini limit reached. ${error.message}',
      );
    }
  }

  Future<Map<String, dynamic>> _identifyPlantWithBackend({
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return _postBackendMap('/api/identify-plant', {
      'fileName': fileName,
      'imageBase64': base64Encode(imageBytes),
    });
  }

  Future<Map<String, dynamic>> _diagnoseDiseaseWithBackend({
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return _postBackendMap('/api/diagnose-disease', {
      'fileName': fileName,
      'imageBase64': base64Encode(imageBytes),
    });
  }

  Future<Map<String, dynamic>> _postBackendMap(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      _backendUri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _backendError(response);
      if (_isQuotaLimit(response.statusCode, message)) {
        throw AiQuotaLimitException(message);
      }
      throw AiServiceException(message);
    }

    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw const AiServiceException(
          'PlantVerse backend returned invalid JSON.');
    }
    return data.cast<String, dynamic>();
  }

  Uri _backendUri(String path) {
    final base = Uri.parse('$_backendBaseUrl/');
    return base.resolve(path.startsWith('/') ? path.substring(1) : path);
  }

  String _backendError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
      if (data['message'] is String) {
        return data['message'] as String;
      }
    } catch (_) {
      // Fall back to the generic status message below.
    }
    return 'PlantVerse backend request failed with status ${response.statusCode}.';
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

  String _openAiStyleError(http.Response response, String provider) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {
      // Fall back to the generic status message below.
    }
    return '$provider request failed with status ${response.statusCode}.';
  }

  bool _isQuotaLimit(int statusCode, String message) {
    final lower = message.toLowerCase();
    return statusCode == 429 ||
        lower.contains('resource_exhausted') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('too many requests');
  }

  Future<Map<String, dynamic>?> _identifyWithExternalProviders({
    required Uint8List imageBytes,
    required String fileName,
    required String fallbackReason,
  }) async {
    final failures = <String>[];

    if (_groqApiKey.isNotEmpty) {
      try {
        final profile = await _identifyWithGroq(
          imageBytes: imageBytes,
          fileName: fileName,
          fallbackReason: fallbackReason,
        );
        return _withFallbackReason(profile, fallbackReason);
      } catch (error) {
        failures.add('Groq unavailable: $error');
      }
    }

    if (_openRouterApiKey.isNotEmpty) {
      try {
        final profile = await _identifyWithOpenRouter(
          imageBytes: imageBytes,
          fileName: fileName,
          fallbackReason: fallbackReason,
        );
        return _withFallbackReason(profile, fallbackReason);
      } catch (error) {
        failures.add('OpenRouter unavailable: $error');
      }
    }

    if (_plantNetApiKey.isNotEmpty) {
      try {
        final profile = await _identifyWithPlantNet(
          imageBytes: imageBytes,
          fileName: fileName,
          fallbackReason: fallbackReason,
        );
        return _withFallbackReason(profile, fallbackReason);
      } catch (error) {
        failures.add('Pl@ntNet unavailable: $error');
      }
    }

    if (_plantIdApiKey.isNotEmpty) {
      try {
        final profile = await _identifyWithPlantId(
          imageBytes: imageBytes,
          fileName: fileName,
          fallbackReason: fallbackReason,
        );
        return _withFallbackReason(profile, fallbackReason);
      } catch (error) {
        failures.add('Plant.id unavailable: $error');
      }
    }

    if (failures.isEmpty) return null;
    return _offlineCatalogProfile(
      imageBytes: imageBytes,
      fileName: fileName,
      fallbackReason:
          '$fallbackReason Backup providers failed: ${failures.join(' | ')}',
    );
  }

  Future<Map<String, dynamic>> _identifyWithGroq({
    required Uint8List imageBytes,
    required String fileName,
    required String fallbackReason,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': _groqVisionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '''
Identify the plant in this image. Return only valid JSON with:
common_name, scientific_name, family, confidence, description, care_difficulty,
native_region, toxicity_level, toxicity_score, water_requirement, water_score,
sunlight_requirement, sunlight_score, temperature_range, humidity_level,
humidity_score, photosynthesis_score, oxygen_output, air_intake, air_release,
health_summary, story_markdown,
human_toxicity, pet_toxicity, toxic_compounds, care_intelligence,
environmental_intelligence.

Use confidence, toxicity_score, water_score, sunlight_score, humidity_score,
and photosynthesis_score from 0 to 1.

human_toxicity must be an object with:
level, severity_score, touch_effects, ingestion_effects, skin_irritation,
child_warning, first_aid.

pet_toxicity must be an object with cats, dogs, and birds. Each must include:
severity, symptoms, emergency_level.

toxic_compounds must be an object with:
summary, harmful_compounds, alkaloids, oxalates, latex, sap_chemicals.

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

If the image is not a plant, set common_name to Unknown and explain in description.
$_knownVisualConfusionGuidance
Return only raw JSON. No markdown. No code blocks.
'''
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${_mimeType(fileName)};base64,${base64Encode(imageBytes)}',
                },
              },
            ],
          }
        ],
        'temperature': 0,
        'max_tokens': 4000,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _openAiStyleError(response, 'Groq');
      if (_isQuotaLimit(response.statusCode, message)) {
        throw AiQuotaLimitException(message);
      }
      throw AiServiceException(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiServiceException('Groq returned no plant match.');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AiServiceException('Groq returned an empty answer.');
    }

    final result = _decodeObject(content);
    final scientificName = _cleanText(result['scientific_name']);
    if (scientificName.isEmpty) {
      result['common_name'] = 'Unknown plant';
    }
    result['recognition_mode'] = 'groq_vision';
    result['reference_sources'] = ['Groq vision AI: https://console.groq.com'];
    return result;
  }

  Future<Map<String, dynamic>> _identifyWithOpenRouter({
    required Uint8List imageBytes,
    required String fileName,
    required String fallbackReason,
  }) async {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openRouterApiKey',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-maverick:free',
        'max_tokens': 4000,
        'temperature': 0,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${_mimeType(fileName)};base64,${base64Encode(imageBytes)}',
                },
              },
              {
                'type': 'text',
                'text': '''
Identify the plant in this image. Return only valid JSON with:
common_name, scientific_name, family, confidence, description,
care_difficulty, native_region, toxicity_level, toxicity_score,
water_requirement, water_score, sunlight_requirement, sunlight_score,
temperature_range, humidity_level, humidity_score, photosynthesis_score,
oxygen_output, air_intake, air_release, health_summary, story_markdown,
human_toxicity, pet_toxicity, toxic_compounds, care_intelligence,
environmental_intelligence.
$_knownVisualConfusionGuidance
Return only raw JSON. No markdown. No code blocks.
'''
              },
            ],
          }
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _openAiStyleError(response, 'OpenRouter');
      if (_isQuotaLimit(response.statusCode, message)) {
        throw AiQuotaLimitException(message);
      }
      throw AiServiceException(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiServiceException('OpenRouter returned no result.');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AiServiceException('OpenRouter returned empty answer.');
    }

    final result = _decodeObject(content);
    result['recognition_mode'] = 'openrouter_vision';
    result['reference_sources'] = [
      'OpenRouter AI: https://openrouter.ai',
    ];
    return result;
  }

  Future<Map<String, dynamic>> _identifyWithPlantNet({
    required Uint8List imageBytes,
    required String fileName,
    required String fallbackReason,
  }) async {
    final uri = Uri.parse(
      'https://my-api.plantnet.org/v2/identify/all',
    ).replace(queryParameters: {
      'api-key': _plantNetApiKey,
      'lang': 'en',
      'include-related-images': 'false',
    });

    final request = http.MultipartRequest('POST', uri)
      ..fields['organs'] = 'leaf'
      ..files.add(
        http.MultipartFile.fromBytes(
          'images',
          imageBytes,
          filename: fileName,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        'PlantNet request failed with status ${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw const AiServiceException('PlantNet returned no plant match.');
    }
    final top = (results.first as Map).cast<String, dynamic>();
    final species = (top['species'] as Map?)?.cast<String, dynamic>() ?? {};
    final scientificName = _cleanText(
      species['scientificNameWithoutAuthor'] ?? species['scientificName'],
    );
    if (scientificName.isEmpty) {
      throw const AiServiceException('PlantNet returned no scientific name.');
    }
    final commonNames = species['commonNames'] is List
        ? (species['commonNames'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final family = _cleanText(
      (species['family'] as Map?)?['scientificName'],
      fallback: 'Plant family not listed',
    );
    final genus = _cleanText((species['genus'] as Map?)?['scientificName']);
    final confidence = (top['score'] is num)
        ? (top['score'] as num).clamp(0, 1).toDouble()
        : 0.50;

    final profile = _externalIdentityProfile(
      provider: 'Pl@ntNet',
      sourceUrl: 'https://my.plantnet.org/',
      commonName: commonNames.isNotEmpty ? commonNames.first : scientificName,
      scientificName: scientificName,
      family: family,
      genus: genus,
      confidence: confidence,
    );
    return _maybeEnrichWithPerenual(profile, scientificName);
  }

  Future<Map<String, dynamic>> _identifyWithPlantId({
    required Uint8List imageBytes,
    required String fileName,
    required String fallbackReason,
  }) async {
    try {
      return await _identifyWithPlantIdV3(
        imageBytes: imageBytes,
        fileName: fileName,
      );
    } catch (v3Error) {
      try {
        return await _identifyWithPlantIdV2(
          imageBytes: imageBytes,
          fileName: fileName,
        );
      } catch (v2Error) {
        throw AiServiceException(
          'Plant.id v3 failed: $v3Error; Plant.id v2 failed: $v2Error',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _identifyWithPlantIdV3({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.plant.id/v3/identification'),
      headers: {
        'Content-Type': 'application/json',
        'Api-Key': _plantIdApiKey,
      },
      body: jsonEncode({
        'images': ['data:image/jpeg;base64,${base64Encode(imageBytes)}'],
        'similar_images': true,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        'Plant.id request failed with status ${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = data['result'];
    final classification = result is Map ? result['classification'] : null;
    final suggestions =
        classification is Map ? classification['suggestions'] : null;
    if (suggestions is! List ||
        suggestions.isEmpty ||
        suggestions.first is! Map) {
      throw const AiServiceException('Plant.id returned no plant match.');
    }

    final top = (suggestions.first as Map).cast<String, dynamic>();
    final scientificName = _cleanText(top['name']);
    if (scientificName.isEmpty) {
      throw const AiServiceException('Plant.id returned no scientific name.');
    }
    final details = (top['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final commonNames = details['common_names'] is List
        ? (details['common_names'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final taxonomy = (details['taxonomy'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final family = _cleanText(
      taxonomy['family'],
      fallback: 'Plant family not listed',
    );
    final confidence = (top['probability'] is num)
        ? (top['probability'] as num).clamp(0, 1).toDouble()
        : 0.50;

    final profile = _externalIdentityProfile(
      provider: 'Plant.id',
      sourceUrl: 'https://www.kindwise.com/plant-id',
      commonName: commonNames.isNotEmpty ? commonNames.first : scientificName,
      scientificName: scientificName,
      family: family,
      genus: scientificName.split(' ').first,
      confidence: confidence,
    );
    return _maybeEnrichWithPerenual(profile, scientificName);
  }

  Future<Map<String, dynamic>> _identifyWithPlantIdV2({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.plant.id/v2/identify'),
      headers: {
        'Content-Type': 'application/json',
        'Api-Key': _plantIdApiKey,
      },
      body: jsonEncode({
        'images': [base64Encode(imageBytes)],
        'plant_details': ['common_names', 'url', 'taxonomy'],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiServiceException(
        'Plant.id v2 request failed with status ${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = data['suggestions'];
    if (suggestions is! List ||
        suggestions.isEmpty ||
        suggestions.first is! Map) {
      throw const AiServiceException('Plant.id v2 returned no plant match.');
    }

    final top = (suggestions.first as Map).cast<String, dynamic>();
    final scientificName = _cleanText(top['plant_name']);
    if (scientificName.isEmpty) {
      throw const AiServiceException(
        'Plant.id v2 returned no scientific name.',
      );
    }
    final details =
        (top['plant_details'] as Map?)?.cast<String, dynamic>() ?? {};
    final commonNames = details['common_names'] is List
        ? (details['common_names'] as List)
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];
    final taxonomy = (details['taxonomy'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final family = _cleanText(
      taxonomy['family'],
      fallback: 'Plant family not listed',
    );
    final confidence = (top['probability'] is num)
        ? (top['probability'] as num).clamp(0, 1).toDouble()
        : 0.50;

    final profile = _externalIdentityProfile(
      provider: 'Plant.id v2',
      sourceUrl: 'https://www.kindwise.com/plant-id',
      commonName: commonNames.isNotEmpty ? commonNames.first : scientificName,
      scientificName: scientificName,
      family: family,
      genus: scientificName.split(' ').first,
      confidence: confidence,
    );
    return _maybeEnrichWithPerenual(profile, scientificName);
  }

  Map<String, dynamic> _externalIdentityProfile({
    required String provider,
    required String sourceUrl,
    required String commonName,
    required String scientificName,
    required String family,
    required String genus,
    required double confidence,
  }) {
    final profile = PlantTaxonomyIndex.taxonomyProfile({
      'canonicalName': scientificName,
      'scientificName': scientificName,
      'family': family,
      'genus': genus.isEmpty ? scientificName.split(' ').first : genus,
      'order': 'Not listed by $provider response',
      'commonNames': [commonName],
      'description':
          'Identified from the uploaded image by $provider. Care and toxicity stay conservative unless enriched by a source-backed care database.',
      'sourceUrl': sourceUrl,
      'gbifKey': provider,
    });
    return {
      ...profile,
      'confidence': confidence,
      'recognition_mode': 'external_api',
      'reference_sources': [
        '$provider plant identification result: $sourceUrl',
        ...((profile['reference_sources'] as List?) ?? const []),
      ],
    };
  }

  Future<Map<String, dynamic>> _maybeEnrichWithPerenual(
    Map<String, dynamic> profile,
    String scientificName,
  ) async {
    if (_perenualApiKey.isEmpty) return profile;

    try {
      final uri = Uri.https('www.perenual.com', '/api/v2/species-list', {
        'key': _perenualApiKey,
        'q': scientificName,
      });
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return profile;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['data'];
      if (items is! List || items.isEmpty || items.first is! Map) {
        return profile;
      }
      final item = (items.first as Map).cast<String, dynamic>();
      final watering = _cleanText(item['watering']);
      final sunlight = item['sunlight'] is List
          ? (item['sunlight'] as List).join(', ')
          : _cleanText(item['sunlight']);
      final cycle = _cleanText(item['cycle']);

      return {
        ...profile,
        'reference_sources': [
          ...((profile['reference_sources'] as List?) ?? const []),
          'Perenual plant data: https://www.perenual.com/docs/api',
        ],
        if (watering.isNotEmpty) 'water_requirement': watering,
        if (sunlight.isNotEmpty) 'sunlight_requirement': sunlight,
        if (cycle.isNotEmpty)
          'health_summary':
              '${profile['health_summary']} Perenual lists the plant cycle as $cycle.',
      };
    } catch (_) {
      return profile;
    }
  }

  String _cleanText(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<Map<String, dynamic>> _offlineCatalogProfile({
    required Uint8List imageBytes,
    required String fileName,
    String? fallbackReason,
  }) async {
    try {
      final profile = OfflinePlantCatalog.identify(
        imageBytes: imageBytes,
        fileName: fileName,
      );
      return _withFallbackReason(profile, fallbackReason);
    } catch (_) {
      final taxonomyRecord = await PlantTaxonomyIndex.matchByNameSignal(
        fileName,
      );
      if (taxonomyRecord != null) {
        return _withFallbackReason(
          PlantTaxonomyIndex.taxonomyProfile(taxonomyRecord),
          fallbackReason,
        );
      }
      return _offlinePlantProfile(fallbackReason: fallbackReason);
    }
  }

  Map<String, dynamic> _withFallbackReason(
    Map<String, dynamic> profile,
    String? fallbackReason,
  ) {
    final reason = fallbackReason?.trim();
    if (reason == null || reason.isEmpty) return profile;
    return {
      ...profile,
      'fallback_reason': reason,
    };
  }

  Map<String, dynamic> _offlinePlantProfile({String? fallbackReason}) {
    return {
      'common_name': 'Unconfirmed plant',
      'scientific_name': 'Species not confirmed offline',
      'family': 'Offline estimate',
      'confidence': 0.28,
      'recognition_mode': 'offline_general',
      if (fallbackReason?.trim().isNotEmpty == true)
        'fallback_reason': fallbackReason!.trim(),
      'last_reference_reviewed': '2026-05-18',
      'reference_sources': [
        'ASPCA toxic and non-toxic plant database: https://www.aspca.org/pet-care/animal-poison-control/toxic-and-non-toxic-plants',
        'NC State Extension poisonous plant resources: https://gardening.ces.ncsu.edu/gardening-plants/poisonous/',
      ],
      'description':
          'PlantVerse Free Mode is active and no reliable local catalog match was found. This is safe general plant-care guidance, not an exact species identification. Live AI is used first whenever a Gemini key is configured; this fallback appears when there is no key or when the Gemini quota/rate limit is reached.',
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
          'Free offline mode is active. To avoid wrong species facts, PlantVerse is showing conservative general plant-care intelligence instead of forcing an uncertain plant name.',
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

  Future<Map<String, dynamic>> _offlineDiagnosis({
    required Uint8List imageBytes,
    required String fileName,
    String? fallbackReason,
  }) async {
    var plantName = 'your plant';
    try {
      final plant = OfflinePlantCatalog.identify(
        imageBytes: imageBytes,
        fileName: fileName,
      );
      plantName = plant['common_name']?.toString() ?? plantName;
    } catch (_) {
      final taxonomyRecord = await PlantTaxonomyIndex.matchByNameSignal(
        fileName,
      );
      if (taxonomyRecord != null) {
        plantName = taxonomyRecord['canonicalName']?.toString() ?? plantName;
      }
    }

    return {
      'diagnosis': 'Offline health review for $plantName',
      'confidence': 0.42,
      if (fallbackReason?.trim().isNotEmpty == true)
        'fallback_reason': fallbackReason!.trim(),
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
