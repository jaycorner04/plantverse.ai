class PlantOxygenMetrics {
  final String hourlyEstimate;
  final String dailyEstimate;

  const PlantOxygenMetrics({
    required this.hourlyEstimate,
    required this.dailyEstimate,
  });

  factory PlantOxygenMetrics.fromResult(Map<String, dynamic>? result) {
    final hourly = _firstMeaningful([
      _nestedText(result, const [
        'environmental_intelligence',
        'oxygen',
        'estimated_hourly_release'
      ]),
      _hourlyLike(_nestedText(result, const [
        'environmental_intelligence',
        'oxygen',
        'estimated_daily_release'
      ])),
      _hourlyLike(_topLevelText(result, 'oxygen_output')),
    ]);

    final resolvedHourly = hourly.isNotEmpty
        ? hourly
        : 'Approx. 2-10 mL oxygen/hour for a small healthy indoor plant in bright light.';

    final daily = _firstMeaningful([
      _dailyLike(_nestedText(result, const [
        'environmental_intelligence',
        'oxygen',
        'estimated_daily_release'
      ])),
      _nestedText(result, const [
        'environmental_intelligence',
        'oxygen',
        'estimated_day_release'
      ]),
      _dailyLike(_topLevelText(result, 'oxygen_output')),
      _dailyFromHourly(resolvedHourly),
    ]);

    return PlantOxygenMetrics(
      hourlyEstimate: resolvedHourly,
      dailyEstimate: daily.isNotEmpty
          ? daily
          : 'Approx. 24-120 mL/day, assuming about 12 productive light hours.',
    );
  }

  static String _topLevelText(Map<String, dynamic>? result, String key) {
    final value = result?[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _nestedText(Map<String, dynamic>? result, List<String> path) {
    dynamic current = result;
    for (final segment in path) {
      if (current is! Map) return '';
      current = current[segment];
    }
    if (current == null) return '';
    return current.toString().trim();
  }

  static String _firstMeaningful(List<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  static String _hourlyLike(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('/hour') ||
        lower.contains('per hour') ||
        lower.contains('hourly')) {
      return value;
    }
    return '';
  }

  static String _dailyLike(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('/hour') ||
        lower.contains('per hour') ||
        lower.contains('hourly')) {
      return '';
    }
    if (lower.contains('/day') ||
        lower.contains('per day') ||
        lower.contains('daily') ||
        lower.contains('daylight')) {
      return value;
    }
    return '';
  }

  static String _dailyFromHourly(String hourly) {
    final range = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:-|to)\s*(\d+(?:\.\d+)?)\s*mL',
      caseSensitive: false,
    ).firstMatch(hourly);
    if (range != null) {
      final low = double.tryParse(range.group(1) ?? '');
      final high = double.tryParse(range.group(2) ?? '');
      if (low != null && high != null) {
        return 'Approx. ${_formatMl(low * 12)}-${_formatMl(high * 12)} mL/day, assuming about 12 productive light hours.';
      }
    }

    final single = RegExp(
      r'(\d+(?:\.\d+)?)\s*mL',
      caseSensitive: false,
    ).firstMatch(hourly);
    final value = double.tryParse(single?.group(1) ?? '');
    if (value != null) {
      return 'Approx. ${_formatMl(value * 12)} mL/day, assuming about 12 productive light hours.';
    }

    return '';
  }

  static String _formatMl(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} L';
    }
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}
