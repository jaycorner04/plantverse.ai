import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../animations/staggered_reveal.dart';
import '../core/constants/app_colors.dart';
import '../core/performance/performance_mode.dart';
import '../features/plant_details/plant_biology_metrics.dart';
import '../services/scan_result_store.dart';
import '../widgets/immersive_background.dart';

class PlantDetailsScreen extends ConsumerWidget {
  final Map<String, dynamic>? result;
  final Uint8List? imageBytes;

  const PlantDetailsScreen({
    super.key,
    this.result,
    this.imageBytes,
  });

  String _value(String key, String fallback) {
    final value = result?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _text(List<String> path, String fallback) {
    dynamic current = result;
    for (final segment in path) {
      if (current is! Map) return fallback;
      current = current[segment];
    }
    if (current == null) return fallback;
    if (current is List) {
      final joined = current
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
      return joined.isEmpty ? fallback : joined;
    }
    final text = current.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _stringList(String key) {
    final value = result?[key];
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  double _score(String key, double fallback) {
    final value = result?[key];
    if (value is num) return value.clamp(0, 1).toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed.clamp(0, 1).toDouble();
    return fallback;
  }

  double _nestedScore(List<String> path, double fallback) {
    dynamic current = result;
    for (final segment in path) {
      if (current is! Map) return fallback;
      current = current[segment];
    }
    if (current is num) return current.clamp(0, 1).toDouble();
    final parsed = double.tryParse(current?.toString() ?? '');
    if (parsed != null) return parsed.clamp(0, 1).toDouble();
    return fallback;
  }

  String get _commonName => _value('common_name', 'Plant Analysis');
  String get _scientificName =>
      _value('scientific_name', 'Scientific name pending');
  String get _family => _value('family', 'Plant Family');
  String get _nativeRegion => _value('native_region', 'Native region unknown');
  String get _temperatureRange => _value('temperature_range', '18-30 C');
  String get _humidityLevel => _value('humidity_level', 'Moderate humidity');
  String get _recognitionMode => _value('recognition_mode', 'live_ai');
  String get _fallbackReason => _value('fallback_reason', '');
  String get _confidenceLabel {
    if (_recognitionMode == 'offline_general') return 'General fallback';
    if (_recognitionMode == 'offline_catalog') return 'Offline catalog';
    if (_recognitionMode == 'offline_taxonomy') return '10k taxonomy';
    if (_recognitionMode == 'external_api') return 'Backup API';
    return '${(_confidence * 100).toStringAsFixed(0)}% AI confidence';
  }

  String get _oxygenOutput => _value(
        'oxygen_output',
        'Small but steady oxygen contribution while leaves receive enough light; exact output varies with plant size and health.',
      );
  PlantOxygenMetrics get _oxygenMetrics =>
      PlantOxygenMetrics.fromResult(result);

  double get _confidence => _score('confidence', 0.72);
  double get _toxicityScore => _score('toxicity_score', _toxicityFallback());
  double get _photosynthesisScore => _nestedScore(
      ['environmental_intelligence', 'oxygen', 'score'],
      _score('photosynthesis_score', _confidence));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(scanResultProvider);
    if (result == null && imageBytes == null && stored != null) {
      return PlantDetailsScreen(
        result: stored.result,
        imageBytes: stored.imageBytes,
      )._buildContent(context);
    }
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: ImmersiveBackground(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _hero(context),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.canvasDark.withOpacity(0.78),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(34)),
                ),
                transform: Matrix4.translationValues(0, -28, 0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 42),
                  child: StaggeredReveal(
                    delay: 80.ms,
                    children: [
                      _identityGrid(),
                      const SizedBox(height: 18),
                      _confidenceCard(),
                      const SizedBox(height: 18),
                      _toxicityIntelligence(),
                      const SizedBox(height: 18),
                      _careIntelligence(),
                      const SizedBox(height: 18),
                      _environmentalIntelligence(),
                      const SizedBox(height: 18),
                      _storyCard(),
                      const SizedBox(height: 18),
                      if (_stringList('reference_sources').isNotEmpty) ...[
                        _referenceSourcesCard(),
                        const SizedBox(height: 18),
                      ],
                      _actions(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final performanceMode = plantVersePerformanceMode(context);
    return SizedBox(
      height: 500,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _heroImage(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.18),
                  AppColors.softBlack.withOpacity(0.94),
                ],
              ),
            ),
          ),
          if (!performanceMode)
            const Positioned.fill(child: _OxygenParticleField()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.softBlack.withOpacity(0.55),
                    child: IconButton(
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: AppColors.pureWhite,
                      ),
                      onPressed: () => context.go('/home'),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: AppColors.softBlack.withOpacity(0.55),
                    child: IconButton(
                      icon: const Icon(
                        LucideIcons.stethoscope,
                        color: AppColors.pureWhite,
                      ),
                      onPressed: () => context.push('/ai_doctor'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _glassChip(
                      LucideIcons.sparkles,
                      _confidenceLabel,
                    ),
                    _glassChip(LucideIcons.leaf, _family),
                    _glassChip(
                      LucideIcons.activity,
                      _text(
                        [
                          'environmental_intelligence',
                          'biology',
                          'photosynthesis_type'
                        ],
                        'Bio intelligence',
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 18),
                Text(
                  _commonName,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 38,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 18)],
                  ),
                ).animate().fadeIn(duration: 700.ms),
                const SizedBox(height: 10),
                Text(
                  'AI biology profile for toxicity, care chemistry, and indoor environmental exchange.',
                  style: TextStyle(
                    color: AppColors.pureWhite.withOpacity(0.72),
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroImage() {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        cacheWidth: 900,
        gaplessPlayback: true,
      );
    }
    return Image.network(
      'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?auto=format&fit=crop&q=85&w=1000',
      fit: BoxFit.cover,
    );
  }

  Widget _identityGrid() {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            icon: LucideIcons.dna,
            label: 'Scientific name',
            value: _scientificName,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoCard(
            icon: LucideIcons.mapPin,
            label: 'Native region',
            value: _nativeRegion,
          ),
        ),
      ],
    );
  }

  Widget _confidenceCard() {
    return _InteractiveScienceCard(
      glowColor: AppColors.actionBlueOnDark,
      child: Row(
        children: [
          _ScienceRing(
            score: _confidence,
            color: AppColors.actionBlueOnDark,
            label: 'AI',
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionEyebrow('Scan interpretation'),
                const SizedBox(height: 7),
                const Text(
                  'Scan interpretation',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _value(
                    'health_summary',
                    _value(
                      'description',
                      'Gemini analyzed visible structure, leaf texture, and care signals from your scan.',
                    ),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.pureWhite.withOpacity(0.68),
                    height: 1.42,
                  ),
                ),
                if (_fallbackReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _fallbackReason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.warningYellow.withOpacity(0.92),
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toxicityIntelligence() {
    final color = _riskColor(_toxicityScore);
    return _sectionShell(
      icon: LucideIcons.shieldAlert,
      title: 'Toxicity intelligence',
      subtitle: 'Human-safe, pet-safe, and compound-level plant risk analysis.',
      accent: color,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Human risk',
                  value: _text(
                    ['human_toxicity', 'level'],
                    _value('toxicity_level', 'Unknown'),
                  ),
                  accent: color,
                  icon: Icons.health_and_safety_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Severity',
                  value: '${(_toxicityScore * 100).toStringAsFixed(0)}%',
                  accent: color,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InteractiveScienceCard(
            glowColor: color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ScienceRing(
                        score: _toxicityScore, color: color, label: ''),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionEyebrow('Human toxicity'),
                          const SizedBox(height: 7),
                          Text(
                            _text(
                              ['human_toxicity', 'child_warning'],
                              'Keep unidentified plant material away from children until toxicity is confirmed.',
                            ),
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 18,
                              height: 1.28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _detailRow(
                  Icons.touch_app_rounded,
                  'If touched',
                  _text(
                    ['human_toxicity', 'touch_effects'],
                    'May cause little to no reaction for most adults; sensitive skin can still react to sap or leaf oils.',
                  ),
                ),
                _detailRow(
                  Icons.restaurant_rounded,
                  'If ingested',
                  _text(
                    ['human_toxicity', 'ingestion_effects'],
                    'Avoid ingestion. Plant material may irritate the mouth or stomach depending on species and dose.',
                  ),
                ),
                _detailRow(
                  Icons.front_hand_rounded,
                  'Skin irritation',
                  _text(
                    ['human_toxicity', 'skin_irritation'],
                    'Wash exposed skin with soap and water if irritation appears.',
                  ),
                ),
                _detailRow(
                  Icons.medical_services_rounded,
                  'First aid',
                  _text(
                    ['human_toxicity', 'first_aid'],
                    'Rinse mouth or skin, remove plant residue, and contact poison control or a clinician if symptoms appear.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _petRiskGrid(),
          const SizedBox(height: 14),
          _compoundCard(),
        ],
      ),
    );
  }

  Widget _petRiskGrid() {
    return Column(
      children: [
        _petRiskCard(
          pet: 'Cats',
          icon: Icons.pets_rounded,
          path: 'cats',
          fallback:
              'May cause vomiting, drooling, or digestive irritation if a toxic species is chewed.',
        ),
        const SizedBox(height: 12),
        _petRiskCard(
          pet: 'Dogs',
          icon: Icons.cruelty_free_rounded,
          path: 'dogs',
          fallback:
              'Watch for mouth irritation, stomach upset, lethargy, or unusual drooling after chewing.',
        ),
        const SizedBox(height: 12),
        _petRiskCard(
          pet: 'Birds',
          icon: Icons.flutter_dash_rounded,
          path: 'birds',
          fallback:
              'Birds are sensitive to plant chemicals; avoid cage access unless the species is known bird-safe.',
        ),
      ],
    );
  }

  Widget _petRiskCard({
    required String pet,
    required IconData icon,
    required String path,
    required String fallback,
  }) {
    final severity = _text(['pet_toxicity', path, 'severity'], 'Unknown');
    final emergency =
        _text(['pet_toxicity', path, 'emergency_level'], 'Monitor closely');
    final score = _riskScoreFromText('$severity $emergency', _toxicityScore);
    final color = _riskColor(score);

    return _InteractiveScienceCard(
      glowColor: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _glowIcon(icon, color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  pet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _riskBadge(emergency, color),
          ),
          const SizedBox(height: 12),
          Text(
            'Severity: $severity',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text(['pet_toxicity', path, 'symptoms'], fallback),
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.70),
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _oxygenProductionCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final performanceMode = plantVersePerformanceMode(context);
        final oxygenMetrics = _oxygenMetrics;
        final ring = _ScienceRing(
          score: _photosynthesisScore,
          color: AppColors.actionBlueOnDark,
          label: 'O2',
          size: compact ? 118 : 96,
        );
        final copy = Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            _sectionEyebrow('Oxygen production'),
            const SizedBox(height: 8),
            Text(
              _oxygenOutput,
              textAlign: compact ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: compact ? 17 : 18,
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: compact ? WrapAlignment.center : WrapAlignment.start,
              children: [
                _OxygenAmountChip(
                  label: 'Per hour',
                  value: oxygenMetrics.hourlyEstimate,
                ),
                _OxygenAmountChip(
                  label: 'Per day',
                  value: oxygenMetrics.dailyEstimate,
                ),
              ],
            ),
          ],
        );

        return Stack(
          children: [
            if (!performanceMode)
              const Positioned.fill(child: _OxygenParticleField()),
            Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 8 : 0),
              child: compact
                  ? Column(
                      children: [
                        ring,
                        const SizedBox(height: 18),
                        copy,
                      ],
                    )
                  : Row(
                      children: [
                        ring,
                        const SizedBox(width: 18),
                        Expanded(child: copy),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _compactOxygenDetail(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.pureWhite.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.pureWhite.withOpacity(0.08)),
                ),
                child: Icon(icon, color: AppColors.actionBlueOnDark, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.pureWhite.withOpacity(0.58),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 15,
              height: 1.42,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compoundCard() {
    return _InteractiveScienceCard(
      glowColor: AppColors.warningYellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _glowIcon(Icons.science_rounded, AppColors.warningYellow),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Scientific toxic compounds',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _text(
              ['toxic_compounds', 'summary'],
              'Compound profile is estimated from the identified species and common botanical toxicology records.',
            ),
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.72),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _compoundPill(
                'Compounds',
                _text(
                  ['toxic_compounds', 'harmful_compounds'],
                  'Not commonly reported',
                ),
              ),
              _compoundPill(
                'Alkaloids',
                _text(
                    ['toxic_compounds', 'alkaloids'], 'Not commonly reported'),
              ),
              _compoundPill(
                'Oxalates',
                _text(['toxic_compounds', 'oxalates'], 'Species dependent'),
              ),
              _compoundPill(
                'Latex',
                _text(['toxic_compounds', 'latex'], 'Not commonly reported'),
              ),
              _compoundPill(
                'Sap',
                _text(
                    ['toxic_compounds', 'sap_chemicals'], 'May irritate skin'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _careIntelligence() {
    return _sectionShell(
      icon: LucideIcons.droplets,
      title: 'Care intelligence',
      subtitle:
          'AI-generated care logic with biological causes, not just meter values.',
      accent: AppColors.emeraldGreen,
      child: Column(
        children: [
          _careSystemCard(
            icon: LucideIcons.droplets,
            title: 'Water rhythm',
            accent: AppColors.actionBlueOnDark,
            score: _nestedScore(['care_intelligence', 'water', 'score'],
                _score('water_score', 0.55)),
            summary: _text(
              ['care_intelligence', 'water', 'ideal_frequency'],
              _value('water_requirement',
                  'Water when the top layer of soil has dried.'),
            ),
            details: [
              _ScienceFact(
                'Amount',
                _text(
                  ['care_intelligence', 'water', 'amount_estimation'],
                  'Use enough water to evenly moisten the root zone without leaving the pot waterlogged.',
                ),
              ),
              _ScienceFact(
                'Overwatering risk',
                _text(
                  ['care_intelligence', 'water', 'overwatering_risk'],
                  'Persistently wet soil can reduce root oxygen and invite root rot.',
                ),
              ),
              _ScienceFact(
                'Underwatering signs',
                _text(
                  ['care_intelligence', 'water', 'underwatering_symptoms'],
                  'Watch for wilting, curling, dry edges, and slow growth.',
                ),
              ),
              _ScienceFact(
                'Seasonal shift',
                _text(
                  ['care_intelligence', 'water', 'seasonal_changes'],
                  'Water less in cool or low-light months and more during active warm growth.',
                ),
              ),
              _ScienceFact(
                'Soil moisture',
                _text(
                  ['care_intelligence', 'water', 'soil_moisture_preference'],
                  'Prefers oxygenated soil with a drying interval between watering cycles.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _careSystemCard(
            icon: LucideIcons.sun,
            title: 'Light environment',
            accent: AppColors.warningYellow,
            score: _nestedScore(['care_intelligence', 'sunlight', 'score'],
                _score('sunlight_score', 0.66)),
            summary: _text(
              ['care_intelligence', 'sunlight', 'indirect_preference'],
              _value('sunlight_requirement',
                  'Thrives in bright indirect light; avoid harsh afternoon sun.'),
            ),
            details: [
              _ScienceFact(
                'Direct sun',
                _text(
                  ['care_intelligence', 'sunlight', 'direct_tolerance'],
                  'Direct sunlight tolerance depends on species and acclimation.',
                ),
              ),
              _ScienceFact(
                'Indoor fit',
                _text(
                  ['care_intelligence', 'sunlight', 'indoor_compatibility'],
                  'Works indoors when placed near a bright window or grow light.',
                ),
              ),
              _ScienceFact(
                'Outdoor fit',
                _text(
                  ['care_intelligence', 'sunlight', 'outdoor_compatibility'],
                  'Move outdoors gradually to avoid leaf scorch.',
                ),
              ),
              _ScienceFact(
                'Best window',
                _text(
                  ['care_intelligence', 'sunlight', 'best_window_direction'],
                  'East or bright filtered south/west light is often ideal indoors.',
                ),
              ),
              _ScienceFact(
                'Heat tolerance',
                _text(
                  ['care_intelligence', 'sunlight', 'heat_tolerance'],
                  'High heat increases transpiration and water demand.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _careSystemCard(
            icon: LucideIcons.cloudSun,
            title: 'Humidity field',
            accent: AppColors.emeraldGreen,
            score: _nestedScore(['care_intelligence', 'humidity', 'score'],
                _score('humidity_score', 0.58)),
            summary: _text(
              ['care_intelligence', 'humidity', 'ideal_humidity'],
              _humidityLevel,
            ),
            details: [
              _ScienceFact(
                'Dry climate',
                _text(
                  ['care_intelligence', 'humidity', 'dry_climate_tolerance'],
                  'Dry air may slow growth or crisp sensitive leaf edges.',
                ),
              ),
              _ScienceFact(
                'Misting',
                _text(
                  ['care_intelligence', 'humidity', 'misting_recommendations'],
                  'Misting gives short-term moisture; humidity trays or grouping plants are steadier.',
                ),
              ),
              _ScienceFact(
                'AC rooms',
                _text(
                  ['care_intelligence', 'humidity', 'ac_room_compatibility'],
                  'Avoid direct AC airflow because it can dehydrate foliage.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _careSystemCard(
            icon: LucideIcons.thermometer,
            title: 'Temperature biology',
            accent: AppColors.softRed,
            score: _nestedScore(
                ['care_intelligence', 'temperature', 'score'], 0.70),
            summary: _text(
              ['care_intelligence', 'temperature', 'best_growth_temperature'],
              _temperatureRange,
            ),
            details: [
              _ScienceFact(
                'Minimum',
                _text(
                  ['care_intelligence', 'temperature', 'minimum_temperature'],
                  'Protect from cold drafts and temperatures below typical indoor comfort.',
                ),
              ),
              _ScienceFact(
                'Maximum',
                _text(
                  ['care_intelligence', 'temperature', 'maximum_temperature'],
                  'Avoid heat stress near hot windows or appliances.',
                ),
              ),
              _ScienceFact(
                'Winter survival',
                _text(
                  ['care_intelligence', 'temperature', 'winter_survival'],
                  'Growth usually slows in winter; reduce water and keep away from cold glass.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _careSystemCard({
    required IconData icon,
    required String title,
    required Color accent,
    required double score,
    required String summary,
    required List<_ScienceFact> details,
  }) {
    return _InteractiveScienceCard(
      glowColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScienceRing(score: score, color: accent, label: ''),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      summary,
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.72),
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: accent, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          ...details.map(
            (fact) =>
                _detailRow(Icons.auto_awesome_rounded, fact.label, fact.value),
          ),
        ],
      ),
    );
  }

  Widget _environmentalIntelligence() {
    return _sectionShell(
      icon: LucideIcons.wind,
      title: 'Environmental exchange',
      subtitle:
          'Oxygen, carbon dioxide, photosynthesis, and respiration estimates.',
      accent: AppColors.actionBlueOnDark,
      child: Column(
        children: [
          _InteractiveScienceCard(
            glowColor: AppColors.actionBlueOnDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _oxygenProductionCard(),
                const SizedBox(height: 14),
                _oxygenChart(),
                const SizedBox(height: 16),
                _detailRow(
                  Icons.wb_sunny_rounded,
                  'Day vs night',
                  _text(
                    ['environmental_intelligence', 'oxygen', 'day_vs_night'],
                    'Oxygen release rises during daylight photosynthesis and drops at night while respiration continues.',
                  ),
                ),
                _detailRow(
                  Icons.air_rounded,
                  'Indoor contribution',
                  _text(
                    [
                      'environmental_intelligence',
                      'oxygen',
                      'indoor_contribution'
                    ],
                    'Indoor oxygen impact is small but biologically meaningful as part of plant-air exchange.',
                  ),
                ),
                _detailRow(
                  Icons.cleaning_services_rounded,
                  'NASA clean air relevance',
                  _text(
                    [
                      'environmental_intelligence',
                      'oxygen',
                      'nasa_clean_air_relevance'
                    ],
                    'Some related houseplants appear in clean-air research, but room-scale purification depends on plant density and ventilation.',
                  ),
                ),
                _detailRow(
                  Icons.calculate_rounded,
                  'Approximation logic',
                  _text(
                    [
                      'environmental_intelligence',
                      'oxygen',
                      'approximation_logic'
                    ],
                    'Estimate is based on visible leaf area, species habit, light preference, maturity, and indoor growing conditions.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InteractiveScienceCard(
            glowColor: AppColors.emeraldGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ScienceRing(
                      score: _nestedScore(
                          ['environmental_intelligence', 'co2', 'score'], 0.54),
                      color: AppColors.emeraldGreen,
                      label: 'CO2',
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionEyebrow('Carbon dioxide absorption'),
                          const SizedBox(height: 7),
                          Text(
                            _text(
                              [
                                'environmental_intelligence',
                                'co2',
                                'estimated_daily_absorption'
                              ],
                              'Absorbs small amounts of carbon dioxide during daylight photosynthesis.',
                            ),
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 18,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(
                  Icons.cyclone_rounded,
                  'Photosynthesis cycle',
                  _text(
                    [
                      'environmental_intelligence',
                      'co2',
                      'photosynthesis_cycle'
                    ],
                    'CO2 is absorbed through stomata during active light-driven photosynthesis.',
                  ),
                ),
                _detailRow(
                  Icons.eco_rounded,
                  'Carbon capture',
                  _text(
                    [
                      'environmental_intelligence',
                      'co2',
                      'carbon_capture_efficiency'
                    ],
                    'Carbon capture is modest indoors but improves with healthy leaves and adequate light.',
                  ),
                ),
                _detailRow(
                  Icons.home_work_rounded,
                  'Air improvement',
                  _text(
                    [
                      'environmental_intelligence',
                      'co2',
                      'indoor_air_improvement'
                    ],
                    'Best viewed as a small contribution to indoor air quality alongside ventilation.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InteractiveScienceCard(
            glowColor: AppColors.warningYellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _glowIcon(Icons.biotech_rounded, AppColors.warningYellow),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Advanced biology',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _detailRow(
                  Icons.grass_rounded,
                  'Photosynthesis type',
                  _text(
                    [
                      'environmental_intelligence',
                      'biology',
                      'photosynthesis_type'
                    ],
                    'Likely C3 unless species-specific evidence suggests CAM or C4.',
                  ),
                ),
                _detailRow(
                  Icons.water_drop_rounded,
                  'Transpiration',
                  _text(
                    [
                      'environmental_intelligence',
                      'biology',
                      'transpiration_details'
                    ],
                    'Leaves release water vapor through stomata, linking humidity, light, and water demand.',
                  ),
                ),
                _detailRow(
                  Icons.account_tree_rounded,
                  'Root oxygen exchange',
                  _text(
                    [
                      'environmental_intelligence',
                      'biology',
                      'root_oxygen_exchange'
                    ],
                    'Roots need oxygen pockets in soil; saturated soil can suffocate root tissue.',
                  ),
                ),
                _detailRow(
                  Icons.bolt_rounded,
                  'Growth respiration',
                  _text(
                    [
                      'environmental_intelligence',
                      'biology',
                      'growth_respiration_details'
                    ],
                    'Stored sugars are respired for growth, repair, and root activity even when lights are off.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _oxygenChart() {
    final dayScore = _photosynthesisScore;
    final nightScore = (dayScore * 0.32).clamp(0.08, 0.45).toDouble();
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.pureWhite.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _chartBar('Morning', dayScore * 0.72, AppColors.emeraldGreen),
          _chartBar('Noon', dayScore, AppColors.actionBlueOnDark),
          _chartBar('Evening', dayScore * 0.58, AppColors.emeraldGreen),
          _chartBar('Night', nightScore, AppColors.warningYellow),
        ],
      ),
    );
  }

  Widget _chartBar(String label, double value, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0.04, 1)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animated, child) {
                  return FractionallySizedBox(
                    heightFactor: animated,
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [color.withOpacity(0.42), color],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.58),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyCard() {
    return _sectionShell(
      icon: LucideIcons.bookOpen,
      title: 'AI-generated story',
      subtitle:
          'Origin, habitat, and care personality translated into plain language.',
      accent: AppColors.emeraldGreen,
      child: Text(
        _value(
          'story_markdown',
          _value(
            'description',
            'Scan a plant to generate its origin story, natural habitat, and care personality.',
          ),
        ),
        style: TextStyle(
          fontSize: 16,
          height: 1.65,
          color: AppColors.pureWhite.withOpacity(0.76),
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _referenceSourcesCard() {
    final sources = _stringList('reference_sources');
    final reviewed = _value('last_reference_reviewed', 'local database');
    return _sectionShell(
      icon: LucideIcons.library,
      title: 'Reference sources',
      subtitle: 'Offline facts packaged from source-backed plant references.',
      accent: AppColors.actionBlueOnDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviewed: $reviewed',
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...sources.map(
            (source) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.link,
                    size: 15,
                    color: AppColors.actionBlueOnDark.withOpacity(0.92),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      source,
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.70),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add to Garden'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: () => context.push('/ai_doctor'),
          icon: const Icon(LucideIcons.stethoscope),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.pureWhite.withOpacity(0.10),
            foregroundColor: AppColors.aiGlow,
            padding: const EdgeInsets.all(18),
          ),
        ),
      ],
    );
  }

  Widget _sectionShell({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _glowIcon(icon, accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 24,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.62),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return _InteractiveScienceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.emeraldGreen, size: 24),
          const SizedBox(height: 26),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.pureWhite.withOpacity(0.54),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              height: 1.16,
              color: AppColors.pureWhite,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.pureWhite.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pureWhite.withOpacity(0.08)),
            ),
            child: Icon(icon, color: AppColors.actionBlueOnDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.pureWhite.withOpacity(0.52),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 15,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compoundPill(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.pureWhite.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.50),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.pureWhite.withOpacity(0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.pureWhite, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionEyebrow(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: AppColors.actionBlueOnDark.withOpacity(0.82),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _glowIcon(IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.30),
            blurRadius: 24,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _riskBadge(String label, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(Color accent) {
    return BoxDecoration(
      color: AppColors.pureWhite.withOpacity(0.065),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.pureWhite.withOpacity(0.105),
          accent.withOpacity(0.045),
          AppColors.tileDark.withOpacity(0.62),
        ],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.pureWhite.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(
          color: accent.withOpacity(0.10),
          blurRadius: 34,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Color _riskColor(double score) {
    if (score >= 0.66) return AppColors.errorRed;
    if (score >= 0.34) return AppColors.warningYellow;
    return AppColors.emeraldGreen;
  }

  double _riskScoreFromText(String text, double fallback) {
    final lower = text.toLowerCase();
    if (lower.contains('emergency') ||
        lower.contains('severe') ||
        lower.contains('high') ||
        lower.contains('danger')) {
      return 0.86;
    }
    if (lower.contains('moderate') ||
        lower.contains('caution') ||
        lower.contains('monitor')) {
      return 0.54;
    }
    if (lower.contains('low') || lower.contains('safe')) return 0.18;
    return fallback;
  }

  double _toxicityFallback() {
    final text = _value('toxicity_level', '').toLowerCase();
    if (text.contains('high') || text.contains('toxic')) return 0.82;
    if (text.contains('low') || text.contains('mild')) return 0.35;
    if (text.contains('none') || text.contains('safe')) return 0.08;
    return 0.45;
  }
}

class _ScienceFact {
  final String label;
  final String value;

  const _ScienceFact(this.label, this.value);
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _InteractiveScienceCard(
      glowColor: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.52),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 17,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveScienceCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final EdgeInsetsGeometry padding;

  const _InteractiveScienceCard({
    required this.child,
    this.glowColor = AppColors.emeraldGreen,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<_InteractiveScienceCard> createState() =>
      _InteractiveScienceCardState();
}

class _InteractiveScienceCardState extends State<_InteractiveScienceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final performanceMode = plantVersePerformanceMode(context);
    final staticCard = Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withOpacity(0.070),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.glowColor.withOpacity(0.11)),
        boxShadow: performanceMode
            ? const []
            : [
                BoxShadow(
                  color: widget.glowColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: widget.child,
    );
    if (performanceMode) return staticCard;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: AppColors.pureWhite.withOpacity(_hovered ? 0.095 : 0.070),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.glowColor.withOpacity(_hovered ? 0.24 : 0.11),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(_hovered ? 0.20 : 0.08),
                blurRadius: _hovered ? 34 : 20,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.24),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ScienceRing extends StatelessWidget {
  final double score;
  final Color color;
  final String label;
  final double size;

  const _ScienceRing({
    required this.score,
    required this.color,
    required this.label,
    this.size = 78,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = score.clamp(0, 1).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: normalized),
        duration: const Duration(milliseconds: 950),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(value: value, color: color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: size > 80 ? 20 : 16,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (label.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.58),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OxygenAmountChip extends StatelessWidget {
  final String label;
  final String value;

  const _OxygenAmountChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.actionBlueOnDark.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.actionBlueOnDark.withOpacity(0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bubble_chart_rounded,
            color: AppColors.actionBlueOnDark,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.pureWhite.withOpacity(0.56),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  const _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = AppColors.pureWhite.withOpacity(0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final progress = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          color.withOpacity(0.25),
          color,
          AppColors.pureWhite.withOpacity(0.92),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class _OxygenParticleField extends StatefulWidget {
  const _OxygenParticleField();

  @override
  State<_OxygenParticleField> createState() => _OxygenParticleFieldState();
}

class _OxygenParticleFieldState extends State<_OxygenParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _OxygenParticlePainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _OxygenParticlePainter extends CustomPainter {
  final double progress;

  const _OxygenParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final baseX = ((i * 47) % 100) / 100;
      final phase = (progress + i * 0.073) % 1;
      final drift = math.sin((phase + i) * math.pi * 2) * 16;
      final x = baseX * size.width + drift;
      final y = size.height - (phase * size.height * 1.15);
      final radius = 1.8 + (i % 4) * 0.7;
      final opacity = (1 - phase).clamp(0.12, 0.58).toDouble();

      paint.color = AppColors.actionBlueOnDark.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);

      paint.color = AppColors.pureWhite.withOpacity(opacity * 0.45);
      canvas.drawCircle(
          Offset(x + radius * 1.8, y - radius), radius * 0.45, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OxygenParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
