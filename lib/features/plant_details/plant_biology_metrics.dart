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
        : 'Approx. 0.002-0.010 L oxygen/hour for a small healthy indoor plant in bright light.';

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
      hourlyEstimate: toLiters(resolvedHourly),
      dailyEstimate: daily.isNotEmpty
          ? toLiters(daily)
          : 'Approx. 0.024-0.120 L/day, assuming about 12 productive light hours.',
    );
  }

  static String toLiters(String value) {
    if (value.trim().isEmpty) return value;
    var converted = value.replaceAllMapped(
      RegExp(
        '(\\d+(?:\\.\\d+)?)\\s*(?:-|\\u2013|\\u2014|to)\\s*(\\d+(?:\\.\\d+)?)\\s*mL\\b',
        caseSensitive: false,
      ),
      (match) {
        final low = double.tryParse(match.group(1) ?? '');
        final high = double.tryParse(match.group(2) ?? '');
        if (low == null || high == null) return match.group(0) ?? '';
        return '${_formatLiters(low / 1000)}-${_formatLiters(high / 1000)} L';
      },
    );
    converted = converted.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*mL\b', caseSensitive: false),
      (match) {
        final amount = double.tryParse(match.group(1) ?? '');
        if (amount == null) return match.group(0) ?? '';
        return '${_formatLiters(amount / 1000)} L';
      },
    );
    return converted;
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
      '(\\d+(?:\\.\\d+)?)\\s*(?:-|\\u2013|\\u2014|to)\\s*(\\d+(?:\\.\\d+)?)\\s*(mL|L)\\b',
      caseSensitive: false,
    ).firstMatch(hourly);
    if (range != null) {
      final low = double.tryParse(range.group(1) ?? '');
      final high = double.tryParse(range.group(2) ?? '');
      final unit = (range.group(3) ?? '').toLowerCase();
      if (low != null && high != null) {
        final lowLiters = unit == 'ml' ? low / 1000 : low;
        final highLiters = unit == 'ml' ? high / 1000 : high;
        return 'Approx. ${_formatLiters(lowLiters * 12)}-${_formatLiters(highLiters * 12)} L/day, assuming about 12 productive light hours.';
      }
    }

    final single = RegExp(
      r'(\d+(?:\.\d+)?)\s*(mL|L)\b',
      caseSensitive: false,
    ).firstMatch(hourly);
    final value = double.tryParse(single?.group(1) ?? '');
    final unit = (single?.group(2) ?? '').toLowerCase();
    if (value != null) {
      final liters = unit == 'ml' ? value / 1000 : value;
      return 'Approx. ${_formatLiters(liters * 12)} L/day, assuming about 12 productive light hours.';
    }

    return '';
  }

  static String _formatLiters(double value) {
    final decimals = value < 0.1
        ? 3
        : value < 1
            ? 2
            : 1;
    var text = value.toStringAsFixed(decimals);
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    return text == '0' ? '0.001' : text;
  }
}
