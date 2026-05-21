import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

class AppUpdateInfo {
  final String latestVersionName;
  final int latestVersionCode;
  final int minSupportedVersionCode;
  final String apkUrl;
  final bool forceUpdate;
  final List<String> releaseNotes;

  const AppUpdateInfo({
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minSupportedVersionCode,
    required this.apkUrl,
    required this.forceUpdate,
    required this.releaseNotes,
  });
}

class AppUpdateService {
  static const _channel = MethodChannel('plantverse.ai/updater');
  static const _definedBackendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL');
  static const _defaultPublicBackendBaseUrl =
      'https://dj2i5my9uyve1.cloudfront.net';
  static const _currentVersionCode =
      int.fromEnvironment('APP_VERSION_CODE', defaultValue: 1);
  static const _currentVersionName =
      String.fromEnvironment('APP_VERSION_NAME', defaultValue: '1.0.0');

  Map<String, String> get _env => dotenv.isInitialized ? dotenv.env : const {};

  String _envValue(String key, String definedValue) {
    final runtimeValue = _env[key]?.trim() ?? '';
    return runtimeValue.isNotEmpty ? runtimeValue : definedValue.trim();
  }

  String get _backendBaseUrl {
    final configured = _envValue(
      'BACKEND_BASE_URL',
      _definedBackendBaseUrl,
    ).replaceAll(RegExp(r'/+$'), '');
    return configured.isNotEmpty ? configured : _defaultPublicBackendBaseUrl;
  }

  int get currentVersionCode => _currentVersionCode;
  String get currentVersionName => _currentVersionName;

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    if (_backendBaseUrl.isEmpty) return null;

    final uri = Uri.parse('$_backendBaseUrl/api/app-version').replace(
      queryParameters: {
        'platform': 'android',
        'currentVersionCode': currentVersionCode.toString(),
        'currentVersionName': currentVersionName,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersionCode = _intValue(data['latest_version_code']);
    final apkUrl = (data['apk_url'] ?? '').toString().trim();
    if (latestVersionCode <= currentVersionCode || apkUrl.isEmpty) {
      return null;
    }

    return AppUpdateInfo(
      latestVersionName:
          (data['latest_version_name'] ?? latestVersionCode.toString())
              .toString(),
      latestVersionCode: latestVersionCode,
      minSupportedVersionCode:
          _intValue(data['min_supported_version_code'], fallback: 1),
      apkUrl: apkUrl,
      forceUpdate: data['force_update'] == true,
      releaseNotes: _stringList(data['release_notes']),
    );
  }

  Future<bool> openUpdate(AppUpdateInfo info) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openUrl',
        {'url': info.apkUrl},
      );
      return opened == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  int _intValue(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
