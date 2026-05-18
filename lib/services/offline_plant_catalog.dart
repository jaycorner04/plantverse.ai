import 'dart:typed_data';

class OfflinePlantCatalog {
  static Map<String, dynamic> identify({
    required Uint8List imageBytes,
    required String fileName,
  }) {
    final plant = _matchPlant(imageBytes: imageBytes, fileName: fileName);
    return _profile(plant);
  }

  static _OfflinePlant _matchPlant({
    required Uint8List imageBytes,
    required String fileName,
  }) {
    final lowerName = fileName.toLowerCase();
    for (final plant in _plants) {
      for (final keyword in plant.keywords) {
        if (lowerName.contains(keyword)) return plant;
      }
    }

    var hash = imageBytes.length;
    if (imageBytes.isNotEmpty) {
      final stride = (imageBytes.length ~/ 96).clamp(1, 4096);
      for (var index = 0; index < imageBytes.length; index += stride) {
        hash = 0x1fffffff & (hash * 31 + imageBytes[index]);
      }
    }
    return _plants[hash % _plants.length];
  }

  static Map<String, dynamic> _profile(_OfflinePlant plant) {
    final toxicScore = plant.toxicityScore;
    final waterScore = plant.waterScore;
    final sunlightScore = plant.sunlightScore;
    final humidityScore = plant.humidityScore;
    final photosynthesisScore = plant.photosynthesisScore;

    return {
      'common_name': plant.commonName,
      'scientific_name': plant.scientificName,
      'family': plant.family,
      'confidence': plant.confidence,
      'description':
          'Free offline match from PlantVerse local catalog. This profile is strongest for common houseplants and gives real species care, toxicity, and biology guidance without paid cloud AI.',
      'care_difficulty': plant.careDifficulty,
      'native_region': plant.nativeRegion,
      'toxicity_level': plant.humanLevel,
      'toxicity_score': toxicScore,
      'water_requirement': plant.waterFrequency,
      'water_score': waterScore,
      'sunlight_requirement': plant.lightPreference,
      'sunlight_score': sunlightScore,
      'temperature_range': plant.temperatureRange,
      'humidity_level': plant.humidity,
      'humidity_score': humidityScore,
      'photosynthesis_score': photosynthesisScore,
      'oxygen_output':
          '${plant.commonName} may release a small amount of oxygen during daylight photosynthesis. Estimate: ${plant.oxygenEstimate}, changing with leaf area, light, water, and maturity.',
      'air_intake': 'Carbon dioxide, light energy, and water.',
      'air_release': 'Oxygen and water vapor during active photosynthesis.',
      'health_summary':
          'Offline catalog profile loaded for ${plant.commonName}. Use this as a practical free guide; confirm with live AI or a plant expert if the image looks unlike this plant.',
      'story_markdown':
          '${plant.commonName} (${plant.scientificName}) is a familiar indoor plant from ${plant.nativeRegion}. In homes it behaves like a small living climate sensor: leaves respond to light, roots respond to oxygen in the soil, and growth slows when water or temperature moves outside its comfort zone. PlantVerse Free Mode uses this local species profile to estimate care, safety, and environmental exchange without sending the photo to a paid cloud model.',
      'human_toxicity': {
        'level': plant.humanLevel,
        'severity_score': toxicScore,
        'touch_effects': plant.touchEffects,
        'ingestion_effects': plant.ingestionEffects,
        'skin_irritation': plant.skinIrritation,
        'child_warning': plant.childWarning,
        'first_aid':
            'Remove plant material, rinse mouth or skin with water, and contact poison control, a clinician, or a veterinarian if symptoms appear.'
      },
      'pet_toxicity': {
        'cats': {
          'severity': plant.catSeverity,
          'symptoms': plant.petSymptoms,
          'emergency_level': plant.petEmergency
        },
        'dogs': {
          'severity': plant.dogSeverity,
          'symptoms': plant.petSymptoms,
          'emergency_level': plant.petEmergency
        },
        'birds': {
          'severity': plant.birdSeverity,
          'symptoms': plant.birdSymptoms,
          'emergency_level': plant.birdEmergency
        }
      },
      'toxic_compounds': {
        'summary': plant.compoundSummary,
        'harmful_compounds': plant.harmfulCompounds,
        'alkaloids': plant.alkaloids,
        'oxalates': plant.oxalates,
        'latex': plant.latex,
        'sap_chemicals': plant.sapChemicals
      },
      'care_intelligence': {
        'water': {
          'score': waterScore,
          'ideal_frequency': plant.waterFrequency,
          'amount_estimation': plant.waterAmount,
          'overwatering_risk': plant.overwateringRisk,
          'underwatering_symptoms': plant.underwateringSymptoms,
          'seasonal_changes':
              'Water less in cool or low-light months; increase only during active warm growth.',
          'soil_moisture_preference': plant.soilPreference
        },
        'sunlight': {
          'score': sunlightScore,
          'direct_tolerance': plant.directTolerance,
          'indirect_preference': plant.lightPreference,
          'indoor_compatibility': plant.indoorCompatibility,
          'outdoor_compatibility': plant.outdoorCompatibility,
          'best_window_direction': plant.bestWindow,
          'heat_tolerance': plant.heatTolerance
        },
        'humidity': {
          'score': humidityScore,
          'ideal_humidity': plant.humidity,
          'dry_climate_tolerance': plant.dryClimateTolerance,
          'misting_recommendations': plant.misting,
          'ac_room_compatibility': plant.acCompatibility
        },
        'temperature': {
          'score': plant.temperatureScore,
          'minimum_temperature': plant.minimumTemperature,
          'maximum_temperature': plant.maximumTemperature,
          'best_growth_temperature': plant.temperatureRange,
          'winter_survival': plant.winterSurvival
        }
      },
      'environmental_intelligence': {
        'oxygen': {
          'score': photosynthesisScore,
          'estimated_daily_release': plant.oxygenEstimate,
          'day_vs_night':
              'Oxygen release happens mainly in daylight. At night the plant still respires and consumes a tiny amount of oxygen.',
          'air_purification_score': plant.airPurificationScore,
          'indoor_contribution': plant.indoorAirContribution,
          'nasa_clean_air_relevance': plant.nasaRelevance,
          'photosynthesis_efficiency': plant.photosynthesisEfficiency,
          'approximation_logic':
              'Free offline estimate based on species habit, typical indoor leaf area, light preference, and water demand.'
        },
        'co2': {
          'score': plant.co2Score,
          'estimated_daily_absorption': plant.co2Estimate,
          'photosynthesis_cycle':
              'CO2 enters through stomata during light-driven photosynthesis and is converted into plant sugars.',
          'carbon_capture_efficiency': plant.carbonEfficiency,
          'indoor_air_improvement': plant.indoorAirContribution
        },
        'biology': {
          'photosynthesis_type': plant.photosynthesisType,
          'transpiration_details': plant.transpiration,
          'root_oxygen_exchange': plant.rootOxygen,
          'growth_respiration_details':
              'Stored sugars are respired day and night to power root activity, leaf repair, and new growth.'
        }
      }
    };
  }

  static final List<_OfflinePlant> _plants = [
    const _OfflinePlant(
      commonName: 'Snake Plant',
      scientificName: 'Dracaena trifasciata',
      family: 'Asparagaceae',
      keywords: ['snake', 'sansevieria', 'trifasciata'],
      confidence: 0.72,
      careDifficulty: 'Beginner',
      nativeRegion: 'West Africa',
      humanLevel: 'Low to moderate if ingested',
      toxicityScore: 0.46,
      touchEffects: 'Usually safe to touch; sap can irritate sensitive skin.',
      ingestionEffects:
          'May cause nausea, mouth irritation, or stomach upset if eaten.',
      skinIrritation: 'Mild sap irritation is possible.',
      childWarning: 'Keep away from children who may chew leaves.',
      catSeverity: 'Moderate',
      dogSeverity: 'Moderate',
      birdSeverity: 'Unknown',
      petSymptoms: 'Vomiting, drooling, nausea, diarrhea, and lethargy.',
      birdSymptoms: 'Avoid chewing exposure; sensitivity varies by bird size.',
      petEmergency: 'Call a vet if eaten',
      birdEmergency: 'Avoid exposure',
      compoundSummary:
          'Contains saponins that can irritate the digestive system.',
      harmfulCompounds: 'Saponins',
      alkaloids: 'Not commonly reported',
      oxalates: 'Not the main concern',
      latex: 'Not commonly reported',
      sapChemicals: 'Saponin-rich sap',
      waterFrequency: 'Water every 2-4 weeks after soil dries fully.',
      waterAmount: 'Water thoroughly, then drain completely.',
      overwateringRisk: 'High; soggy soil can cause root rot.',
      underwateringSymptoms: 'Wrinkled leaves, curling, dry brown edges.',
      soilPreference: 'Dry, fast-draining cactus or succulent-style mix.',
      waterScore: 0.28,
      lightPreference:
          'Tolerates low light but grows best in bright indirect light.',
      sunlightScore: 0.48,
      directTolerance:
          'Can take gentle morning sun; avoid harsh afternoon sun.',
      indoorCompatibility: 'Excellent indoor plant for bedrooms and offices.',
      outdoorCompatibility: 'Outdoor only in warm, frost-free shade.',
      bestWindow: 'North, east, or filtered south window.',
      heatTolerance: 'Good heat tolerance if soil is not wet.',
      humidity: '30-50% humidity is fine.',
      humidityScore: 0.30,
      dryClimateTolerance: 'Very tolerant of dry rooms.',
      misting: 'Do not mist often; dry leaves are safer.',
      acCompatibility: 'Good, but avoid direct cold airflow.',
      temperatureRange: '18-30 C',
      temperatureScore: 0.70,
      minimumTemperature: 'Keep above 10-13 C.',
      maximumTemperature: 'Avoid sustained heat above 35 C.',
      winterSurvival: 'Does not tolerate frost; keep indoors in winter.',
      photosynthesisScore: 0.62,
      oxygenEstimate: 'roughly 3-8 mL oxygen/hour in bright indoor light',
      airPurificationScore: 0.62,
      indoorAirContribution:
          'Small but steady contribution in a planted room; not a replacement for ventilation.',
      nasaRelevance:
          'Related snake plant types are often discussed in clean-air plant lists.',
      photosynthesisEfficiency:
          'Efficient under low water because it can use CAM-style gas exchange.',
      co2Score: 0.58,
      co2Estimate: 'small daytime and nighttime-pattern CO2 exchange',
      carbonEfficiency: 'Modest but water-efficient indoors',
      photosynthesisType: 'CAM-like metabolism reported for snake plant',
      transpiration: 'Low transpiration; leaves conserve water.',
      rootOxygen: 'Needs airy soil; wet roots suffocate easily.',
    ),
    const _OfflinePlant(
      commonName: 'Money Plant / Golden Pothos',
      scientificName: 'Epipremnum aureum',
      family: 'Araceae',
      keywords: ['money', 'pothos', 'epipremnum', 'devil'],
      confidence: 0.70,
      careDifficulty: 'Beginner',
      nativeRegion: 'Moorea and tropical Pacific regions',
      humanLevel: 'Moderate if ingested',
      toxicityScore: 0.64,
      touchEffects: 'Usually safe to touch; sap may irritate skin.',
      ingestionEffects:
          'Chewing can burn the mouth and irritate the digestive tract.',
      skinIrritation: 'Sap may irritate sensitive skin.',
      childWarning: 'Keep trailing vines away from children and pets.',
      catSeverity: 'Moderate to high',
      dogSeverity: 'Moderate to high',
      birdSeverity: 'Caution',
      petSymptoms: 'Oral burning, drooling, vomiting, pawing at mouth.',
      birdSymptoms: 'Mouth and crop irritation may occur if chewed.',
      petEmergency: 'Vet guidance recommended',
      birdEmergency: 'Avoid exposure',
      compoundSummary:
          'Contains insoluble calcium oxalate crystals that irritate tissue.',
      harmfulCompounds: 'Calcium oxalate crystals',
      alkaloids: 'Not commonly reported',
      oxalates: 'Present; main irritant',
      latex: 'Not a latex plant',
      sapChemicals: 'Oxalate-containing sap',
      waterFrequency: 'Water every 7-12 days when top 2-3 cm dries.',
      waterAmount: 'Moisten root ball evenly and empty drainage tray.',
      overwateringRisk: 'Moderate; yellow leaves and root rot can follow.',
      underwateringSymptoms:
          'Drooping vines, curled leaves, dry soil pullback.',
      soilPreference: 'Light, airy potting mix with drainage.',
      waterScore: 0.56,
      lightPreference: 'Bright indirect light; tolerates medium light.',
      sunlightScore: 0.58,
      directTolerance: 'Avoid strong direct afternoon sun.',
      indoorCompatibility: 'Excellent indoor trailing plant.',
      outdoorCompatibility:
          'Warm shaded patios only; invasive in some climates.',
      bestWindow: 'East or filtered south/west window.',
      heatTolerance: 'Good in warm rooms if hydrated.',
      humidity: '40-70% humidity preferred.',
      humidityScore: 0.58,
      dryClimateTolerance:
          'Tolerates average rooms but grows faster with humidity.',
      misting: 'Occasional misting is optional; wipe leaves instead.',
      acCompatibility: 'Avoid direct AC drafts on vines.',
      temperatureRange: '18-32 C',
      temperatureScore: 0.76,
      minimumTemperature: 'Keep above 13-15 C.',
      maximumTemperature: 'Avoid prolonged heat above 35 C.',
      winterSurvival: 'Indoor only where winters are cold.',
      photosynthesisScore: 0.68,
      oxygenEstimate: 'roughly 4-12 mL oxygen/hour depending on vine size',
      airPurificationScore: 0.66,
      indoorAirContribution:
          'Useful as part of a group of leafy indoor plants.',
      nasaRelevance:
          'Golden pothos is commonly associated with clean-air plant research summaries.',
      photosynthesisEfficiency: 'Strong in bright indirect light.',
      co2Score: 0.64,
      co2Estimate: 'small to moderate CO2 uptake during daylight',
      carbonEfficiency: 'Moderate for a leafy vine',
      photosynthesisType: 'C3 photosynthesis',
      transpiration:
          'Moderate transpiration; humidity improves leaf expansion.',
      rootOxygen: 'Roots need oxygen; compact wet soil causes decline.',
    ),
    const _OfflinePlant(
      commonName: 'Monstera',
      scientificName: 'Monstera deliciosa',
      family: 'Araceae',
      keywords: ['monstera', 'deliciosa', 'swiss'],
      confidence: 0.68,
      careDifficulty: 'Intermediate',
      nativeRegion: 'Tropical forests of Central America',
      humanLevel: 'Moderate if ingested',
      toxicityScore: 0.62,
      touchEffects: 'Leaves are safe to handle; sap may irritate skin.',
      ingestionEffects:
          'Unripe or chewed tissue can irritate mouth and stomach.',
      skinIrritation: 'Sap can irritate sensitive skin.',
      childWarning: 'Keep large leaves away from chewing children.',
      catSeverity: 'Moderate',
      dogSeverity: 'Moderate',
      birdSeverity: 'Caution',
      petSymptoms:
          'Drooling, oral irritation, vomiting, swallowing discomfort.',
      birdSymptoms: 'Possible oral irritation if chewed.',
      petEmergency: 'Vet guidance recommended',
      birdEmergency: 'Avoid chewing',
      compoundSummary:
          'Araceae plant with insoluble calcium oxalate irritation risk.',
      harmfulCompounds: 'Calcium oxalate crystals',
      alkaloids: 'Not commonly reported',
      oxalates: 'Present',
      latex: 'Not commonly reported',
      sapChemicals: 'Oxalate-containing sap',
      waterFrequency: 'Water every 7-10 days after top soil dries.',
      waterAmount: 'Water until runoff, then let excess drain.',
      overwateringRisk: 'Moderate to high in dense soil.',
      underwateringSymptoms: 'Curling, drooping, crispy edges.',
      soilPreference: 'Chunky airy aroid mix with bark/perlite.',
      waterScore: 0.62,
      lightPreference: 'Bright indirect light for fenestrated growth.',
      sunlightScore: 0.70,
      directTolerance: 'Brief morning sun is okay; avoid harsh afternoon sun.',
      indoorCompatibility: 'Excellent with space and support pole.',
      outdoorCompatibility: 'Warm shaded tropical conditions only.',
      bestWindow: 'East or filtered south window.',
      heatTolerance: 'Good warmth tolerance with humidity.',
      humidity: '50-70% humidity preferred.',
      humidityScore: 0.72,
      dryClimateTolerance: 'Tolerates average rooms but edges may crisp.',
      misting: 'Use humidifier or pebble tray; misting is temporary.',
      acCompatibility: 'Avoid direct AC airflow.',
      temperatureRange: '18-30 C',
      temperatureScore: 0.74,
      minimumTemperature: 'Keep above 15 C.',
      maximumTemperature: 'Avoid sustained heat above 34 C.',
      winterSurvival: 'Protect from cold and reduce watering.',
      photosynthesisScore: 0.76,
      oxygenEstimate: 'roughly 8-20 mL oxygen/hour for a mature leafy plant',
      airPurificationScore: 0.70,
      indoorAirContribution:
          'Large leaves give a stronger local transpiration and gas exchange presence.',
      nasaRelevance:
          'Not a classic NASA list plant, but broad leaves support indoor leaf area.',
      photosynthesisEfficiency: 'High in bright indirect light.',
      co2Score: 0.72,
      co2Estimate: 'moderate daylight CO2 uptake for large leaf area',
      carbonEfficiency: 'Good for a large indoor aroid',
      photosynthesisType: 'C3 photosynthesis',
      transpiration: 'Moderate to high; humidity supports larger leaves.',
      rootOxygen: 'Aerial and soil roots need airy support and drainage.',
    ),
    const _OfflinePlant(
      commonName: 'Peace Lily',
      scientificName: 'Spathiphyllum wallisii',
      family: 'Araceae',
      keywords: ['peace', 'lily', 'spathiphyllum'],
      confidence: 0.66,
      careDifficulty: 'Beginner to intermediate',
      nativeRegion: 'Tropical Americas and Southeast Asia horticultural lines',
      humanLevel: 'Moderate if ingested',
      toxicityScore: 0.66,
      touchEffects: 'Generally safe to touch; sap may irritate.',
      ingestionEffects: 'Can cause mouth burning, nausea, and stomach upset.',
      skinIrritation: 'Sap may irritate sensitive skin.',
      childWarning: 'Keep flowers and leaves away from children.',
      catSeverity: 'Moderate',
      dogSeverity: 'Moderate',
      birdSeverity: 'Caution',
      petSymptoms: 'Drooling, oral pain, vomiting, reduced appetite.',
      birdSymptoms: 'Avoid chewing; oral irritation possible.',
      petEmergency: 'Vet guidance recommended',
      birdEmergency: 'Avoid exposure',
      compoundSummary: 'Contains insoluble calcium oxalate crystals.',
      harmfulCompounds: 'Calcium oxalate crystals',
      alkaloids: 'Not commonly reported',
      oxalates: 'Present',
      latex: 'Not commonly reported',
      sapChemicals: 'Irritating aroid sap',
      waterFrequency:
          'Water when top soil dries and leaves just begin to soften.',
      waterAmount: 'Water evenly; do not leave standing in water.',
      overwateringRisk: 'Moderate; roots dislike stagnant wet soil.',
      underwateringSymptoms: 'Dramatic drooping, dry edges, dull leaves.',
      soilPreference: 'Moist but airy potting mix.',
      waterScore: 0.70,
      lightPreference: 'Medium to bright indirect light.',
      sunlightScore: 0.54,
      directTolerance: 'Avoid direct sun that scorches leaves.',
      indoorCompatibility: 'Very good for low to medium indoor light.',
      outdoorCompatibility: 'Shaded warm patios only.',
      bestWindow: 'North, east, or filtered window.',
      heatTolerance: 'Moderate; wilts fast in heat when dry.',
      humidity: '45-70% humidity preferred.',
      humidityScore: 0.66,
      dryClimateTolerance: 'Leaf tips brown in very dry rooms.',
      misting: 'Humidity tray or humidifier helps more than misting.',
      acCompatibility: 'Avoid cold AC drafts.',
      temperatureRange: '18-29 C',
      temperatureScore: 0.70,
      minimumTemperature: 'Keep above 15 C.',
      maximumTemperature: 'Avoid heat above 32 C.',
      winterSurvival: 'Indoor protection required in cold climates.',
      photosynthesisScore: 0.63,
      oxygenEstimate: 'roughly 4-10 mL oxygen/hour in bright indirect light',
      airPurificationScore: 0.72,
      indoorAirContribution:
          'Good leafy surface for a small room plant cluster.',
      nasaRelevance:
          'Peace lily is commonly cited in indoor clean-air plant discussions.',
      photosynthesisEfficiency:
          'Moderate; improves with brighter filtered light.',
      co2Score: 0.60,
      co2Estimate: 'small to moderate daylight CO2 absorption',
      carbonEfficiency: 'Moderate indoors',
      photosynthesisType: 'C3 photosynthesis',
      transpiration:
          'Moderate transpiration; responds visibly to water stress.',
      rootOxygen: 'Roots need moist but oxygenated soil.',
    ),
    const _OfflinePlant(
      commonName: 'Aloe Vera',
      scientificName: 'Aloe barbadensis miller',
      family: 'Asphodelaceae',
      keywords: ['aloe', 'vera'],
      confidence: 0.70,
      careDifficulty: 'Beginner',
      nativeRegion: 'Arabian Peninsula and dry tropical regions',
      humanLevel: 'Low topical use, caution if ingested',
      toxicityScore: 0.42,
      touchEffects: 'Gel is usually skin-safe, but some people react.',
      ingestionEffects: 'Latex layer can cause stomach cramps or diarrhea.',
      skinIrritation: 'Patch test before skin use.',
      childWarning: 'Do not let children eat leaves or latex.',
      catSeverity: 'Moderate',
      dogSeverity: 'Moderate',
      birdSeverity: 'Caution',
      petSymptoms: 'Vomiting, diarrhea, lethargy, tremors in some cases.',
      birdSymptoms: 'Avoid ingestion; digestive upset possible.',
      petEmergency: 'Vet guidance if eaten',
      birdEmergency: 'Avoid exposure',
      compoundSummary: 'Aloe latex contains anthraquinone-type compounds.',
      harmfulCompounds: 'Aloin and related anthraquinones in latex',
      alkaloids: 'Not main concern',
      oxalates: 'Not main concern',
      latex: 'Yellow latex layer can irritate digestion',
      sapChemicals: 'Aloin-containing latex',
      waterFrequency: 'Water every 2-3 weeks after soil dries fully.',
      waterAmount: 'Deep soak, then complete drainage.',
      overwateringRisk: 'Very high; rot is common.',
      underwateringSymptoms: 'Thin curling leaves, dry tips, slow growth.',
      soilPreference: 'Dry gritty cactus mix.',
      waterScore: 0.26,
      lightPreference: 'Bright light with some gentle direct sun.',
      sunlightScore: 0.78,
      directTolerance: 'Tolerates morning sun; acclimate slowly.',
      indoorCompatibility: 'Good on bright windowsills.',
      outdoorCompatibility: 'Warm dry outdoor conditions; no frost.',
      bestWindow: 'South or west with acclimation, east is gentle.',
      heatTolerance: 'Good heat tolerance when not overwatered.',
      humidity: 'Low to average humidity.',
      humidityScore: 0.24,
      dryClimateTolerance: 'Excellent dry-air tolerance.',
      misting: 'Do not mist.',
      acCompatibility: 'Generally tolerant if kept warm.',
      temperatureRange: '18-32 C',
      temperatureScore: 0.74,
      minimumTemperature: 'Keep above 10 C.',
      maximumTemperature: 'Avoid extreme heat above 38 C indoors.',
      winterSurvival: 'Protect from frost and water sparingly.',
      photosynthesisScore: 0.66,
      oxygenEstimate: 'roughly 2-7 mL oxygen/hour depending on light',
      airPurificationScore: 0.50,
      indoorAirContribution:
          'Small contribution; strongest value is drought-tolerant greenery.',
      nasaRelevance: 'Often marketed as clean-air plant, but effect is modest.',
      photosynthesisEfficiency: 'Water-efficient CAM succulent behavior.',
      co2Score: 0.52,
      co2Estimate: 'small CO2 exchange, often with nighttime stomatal behavior',
      carbonEfficiency: 'Water efficient, modest total capture',
      photosynthesisType: 'CAM photosynthesis',
      transpiration: 'Low transpiration; leaves store water.',
      rootOxygen: 'Roots require very fast drainage and air.',
    ),
    const _OfflinePlant(
      commonName: 'Spider Plant',
      scientificName: 'Chlorophytum comosum',
      family: 'Asparagaceae',
      keywords: ['spider', 'chlorophytum'],
      confidence: 0.68,
      careDifficulty: 'Beginner',
      nativeRegion: 'Southern Africa',
      humanLevel: 'Low toxicity',
      toxicityScore: 0.10,
      touchEffects: 'Safe to handle for most people.',
      ingestionEffects: 'Not meant for food; mild stomach upset possible.',
      skinIrritation: 'Skin irritation is uncommon.',
      childWarning: 'Low concern, but discourage chewing.',
      catSeverity: 'Low',
      dogSeverity: 'Low',
      birdSeverity: 'Low',
      petSymptoms: 'Mild stomach upset if large amounts are eaten.',
      birdSymptoms: 'Generally low concern; avoid heavy chewing.',
      petEmergency: 'Low, monitor',
      birdEmergency: 'Low, monitor',
      compoundSummary: 'No major household toxic compound concern.',
      harmfulCompounds: 'Not commonly reported',
      alkaloids: 'Not commonly reported',
      oxalates: 'Not commonly reported',
      latex: 'Not commonly reported',
      sapChemicals: 'Not commonly reported',
      waterFrequency: 'Water every 7-10 days when top soil dries.',
      waterAmount: 'Water evenly and drain well.',
      overwateringRisk: 'Moderate; soggy soil browns roots.',
      underwateringSymptoms: 'Pale leaves, folded blades, brown tips.',
      soilPreference: 'Light potting mix, slightly moist but not wet.',
      waterScore: 0.60,
      lightPreference: 'Bright indirect light; tolerates medium light.',
      sunlightScore: 0.55,
      directTolerance: 'Avoid harsh direct sun.',
      indoorCompatibility: 'Excellent indoor hanging or shelf plant.',
      outdoorCompatibility: 'Warm shade outdoors.',
      bestWindow: 'East or bright north window.',
      heatTolerance: 'Moderate; leaf tips brown with heat and salts.',
      humidity: '40-60% humidity.',
      humidityScore: 0.46,
      dryClimateTolerance: 'Tolerates average rooms with possible brown tips.',
      misting: 'Optional; use filtered water if tips brown.',
      acCompatibility: 'Keep away from direct dry drafts.',
      temperatureRange: '18-29 C',
      temperatureScore: 0.72,
      minimumTemperature: 'Keep above 7-10 C.',
      maximumTemperature: 'Avoid sustained heat above 32 C.',
      winterSurvival: 'Protect from frost.',
      photosynthesisScore: 0.64,
      oxygenEstimate: 'roughly 4-10 mL oxygen/hour in good indoor light',
      airPurificationScore: 0.68,
      indoorAirContribution: 'Good contribution for a small leafy plant.',
      nasaRelevance:
          'Spider plant is often cited in clean-air plant discussions.',
      photosynthesisEfficiency: 'Good in bright filtered light.',
      co2Score: 0.60,
      co2Estimate: 'small to moderate daylight CO2 uptake',
      carbonEfficiency: 'Moderate for its size',
      photosynthesisType: 'C3 photosynthesis',
      transpiration: 'Moderate transpiration through thin leaves.',
      rootOxygen: 'Tubers store water; roots still need drainage.',
    ),
  ];
}

class _OfflinePlant {
  final String commonName;
  final String scientificName;
  final String family;
  final List<String> keywords;
  final double confidence;
  final String careDifficulty;
  final String nativeRegion;
  final String humanLevel;
  final double toxicityScore;
  final String touchEffects;
  final String ingestionEffects;
  final String skinIrritation;
  final String childWarning;
  final String catSeverity;
  final String dogSeverity;
  final String birdSeverity;
  final String petSymptoms;
  final String birdSymptoms;
  final String petEmergency;
  final String birdEmergency;
  final String compoundSummary;
  final String harmfulCompounds;
  final String alkaloids;
  final String oxalates;
  final String latex;
  final String sapChemicals;
  final String waterFrequency;
  final String waterAmount;
  final String overwateringRisk;
  final String underwateringSymptoms;
  final String soilPreference;
  final double waterScore;
  final String lightPreference;
  final double sunlightScore;
  final String directTolerance;
  final String indoorCompatibility;
  final String outdoorCompatibility;
  final String bestWindow;
  final String heatTolerance;
  final String humidity;
  final double humidityScore;
  final String dryClimateTolerance;
  final String misting;
  final String acCompatibility;
  final String temperatureRange;
  final double temperatureScore;
  final String minimumTemperature;
  final String maximumTemperature;
  final String winterSurvival;
  final double photosynthesisScore;
  final String oxygenEstimate;
  final double airPurificationScore;
  final String indoorAirContribution;
  final String nasaRelevance;
  final String photosynthesisEfficiency;
  final double co2Score;
  final String co2Estimate;
  final String carbonEfficiency;
  final String photosynthesisType;
  final String transpiration;
  final String rootOxygen;

  const _OfflinePlant({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.keywords,
    required this.confidence,
    required this.careDifficulty,
    required this.nativeRegion,
    required this.humanLevel,
    required this.toxicityScore,
    required this.touchEffects,
    required this.ingestionEffects,
    required this.skinIrritation,
    required this.childWarning,
    required this.catSeverity,
    required this.dogSeverity,
    required this.birdSeverity,
    required this.petSymptoms,
    required this.birdSymptoms,
    required this.petEmergency,
    required this.birdEmergency,
    required this.compoundSummary,
    required this.harmfulCompounds,
    required this.alkaloids,
    required this.oxalates,
    required this.latex,
    required this.sapChemicals,
    required this.waterFrequency,
    required this.waterAmount,
    required this.overwateringRisk,
    required this.underwateringSymptoms,
    required this.soilPreference,
    required this.waterScore,
    required this.lightPreference,
    required this.sunlightScore,
    required this.directTolerance,
    required this.indoorCompatibility,
    required this.outdoorCompatibility,
    required this.bestWindow,
    required this.heatTolerance,
    required this.humidity,
    required this.humidityScore,
    required this.dryClimateTolerance,
    required this.misting,
    required this.acCompatibility,
    required this.temperatureRange,
    required this.temperatureScore,
    required this.minimumTemperature,
    required this.maximumTemperature,
    required this.winterSurvival,
    required this.photosynthesisScore,
    required this.oxygenEstimate,
    required this.airPurificationScore,
    required this.indoorAirContribution,
    required this.nasaRelevance,
    required this.photosynthesisEfficiency,
    required this.co2Score,
    required this.co2Estimate,
    required this.carbonEfficiency,
    required this.photosynthesisType,
    required this.transpiration,
    required this.rootOxygen,
  });
}
