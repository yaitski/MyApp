// lib/services/download_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/resource.dart';
import 'dart:math';

class DownloadService {
  final http.Client _client = http.Client();
  String? _accessToken;

  // Базовый URL для запросов
  static const String baseUrl = 'https://appmyid.open4u.ru';

  // Кэшируем данные устройства
  static Map<String, dynamic>? _deviceInfo;
  static String? _deviceId;

  void setAccessToken(String token) {
    _accessToken = token;
  }

  // Метод для получения информации об устройстве
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    if (_deviceInfo != null) return _deviceInfo!;

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      Map<String, dynamic> info = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        info = {
          'device_id': androidInfo.id ?? _getFallbackDeviceId(),
          'platform': 'android',
          'os_version': androidInfo.version.release ?? 'unknown',
          'device_model': androidInfo.model ?? 'unknown',
          'manufacturer': androidInfo.manufacturer ?? 'unknown',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        info = {
          'device_id': iosInfo.identifierForVendor ?? _getFallbackDeviceId(),
          'platform': 'ios',
          'os_version': iosInfo.systemVersion ?? 'unknown',
          'device_model': iosInfo.model ?? 'unknown',
          'manufacturer': 'Apple',
        };
      } else {
        info = {
          'device_id': _getFallbackDeviceId(),
          'platform': Platform.operatingSystem,
          'os_version': 'unknown',
          'device_model': 'unknown',
          'manufacturer': 'unknown',
        };
      }

      // Добавляем общие параметры
      info['app_version'] = packageInfo.version ?? '1.0.0';
      info['build_number'] = packageInfo.buildNumber ?? '1';
      info['device_language'] = Platform.localeName;

      _deviceInfo = info;
      return info;
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
      // Возвращаем базовую информацию в случае ошибки
      return {
        'device_id': _getFallbackDeviceId(),
        'platform': Platform.operatingSystem,
        'os_version': 'unknown',
        'device_model': 'unknown',
        'manufacturer': 'unknown',
        'app_version': '1.0.0',
        'build_number': '1',
        'device_language': Platform.localeName,
      };
    }
  }

  String _getFallbackDeviceId() {
    if (_deviceId == null) {
      // Генерируем уникальный ID если настоящий недоступен
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';
    }
    return _deviceId!;
  }

  // Получаем размер экрана
  Map<String, dynamic> _getScreenSize() {
    try {
      // В реальном приложении нужно получить MediaQuery
      // В сервисе это сделать сложно, поэтому будем передавать извне
      return {
        'screen_width': 0.0,
        'screen_height': 0.0,
      };
    } catch (e) {
      return {
        'screen_width': 0.0,
        'screen_height': 0.0,
      };
    }
  }

  // Получаем IP адрес (если доступен)
  Future<String?> _getIpAddress() async {
    try {
      // В реальном приложении можно использовать пакет для получения IP
      // Или просто не отправлять его, если сервер не требует
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ManifestResponse> fetchManifest({
    String? etag,
    String? languageCode,
    Map<String, dynamic>? extraParams,
  }) async {
    try {
      final manifestUrl = '$baseUrl/manifest';
      debugPrint('📡 Fetching manifest from: $manifestUrl');

      // Получаем информацию об устройстве
      final deviceInfo = await _getDeviceInfo();

      // Формируем тело запроса
      final Map<String, dynamic> requestBody = {
        'device_id': deviceInfo['device_id'],
        'platform': deviceInfo['platform'],
        'os_version': deviceInfo['os_version'],
        'device_model': deviceInfo['device_model'],
        'manufacturer': deviceInfo['manufacturer'],
        'app_version': deviceInfo['app_version'],
        'build_number': deviceInfo['build_number'],
        'device_language': deviceInfo['device_language'],
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Добавляем ETag если есть
      if (etag != null) {
        requestBody['etag'] = etag;
      }

      // Добавляем язык если есть
      if (languageCode != null) {
        requestBody['language'] = languageCode;
      }

      // Добавляем дополнительный параметры
      if (extraParams != null) {
        requestBody.addAll(extraParams);
      }

      // Пытаемся получить IP адрес
      final ipAddress = await _getIpAddress();
      if (ipAddress != null) {
        requestBody['ip_address'] = ipAddress;
      }

      // Добавляем размер экрана если доступен
      final screenSize = _getScreenSize();
      if (screenSize['screen_width'] > 0) {
        requestBody['screen_width'] = screenSize['screen_width'];
        requestBody['screen_height'] = screenSize['screen_height'];
      }

      debugPrint('📡 Request body: ${jsonEncode(requestBody)}');

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

      final response = await _client.post(
        Uri.parse(manifestUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('📡 Manifest response status: ${response.statusCode}');
      debugPrint('📡 Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final body = response.body;
        final etagHeader = response.headers['etag'];

        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          debugPrint('📡 Manifest received successfully');

          final manifestEtag = etagHeader ?? json['etag'] as String?;
          if (manifestEtag == null) {
            return ManifestResponse.error('Missing ETag');
          }

          return ManifestResponse.success(json, manifestEtag);
        } catch (e) {
          debugPrint('❌ Invalid JSON: $e');
          debugPrint('📄 Response body: $body');
          return ManifestResponse.error('Invalid JSON: $e');
        }
      } else if (response.statusCode == 304) {
        final etagHeader = response.headers['etag'];
        if (etagHeader == null) {
          return ManifestResponse.error('Missing ETag header for 304');
        }
        debugPrint('📡 Manifest not modified (304)');
        return ManifestResponse.notModified(etagHeader);
      } else if (response.statusCode == 401) {
        debugPrint('❌ Unauthorized (401)');
        return ManifestResponse.unauthorized();
      } else if (response.statusCode == 500) {
        try {
          final body = jsonDecode(response.body);
          final error = body['error'] as String?;
          final message = body['message'] as String?;
          debugPrint('❌ Server error: $error - $message');
          return ManifestResponse.error('Server error: $error - $message');
        } catch (_) {
          debugPrint('❌ Server error: ${response.statusCode}');
          return ManifestResponse.error('Server error: ${response.statusCode}');
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        debugPrint('📄 Response body: ${response.body}');
        return ManifestResponse.error('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Network error: $e');
      return ManifestResponse.error('Network error: $e');
    }
  }

  Future<DownloadResult> downloadResource(Resource resource) async {
    try {
      debugPrint('📥 Downloading: ${resource.url}');

      final response = await _client.get(
        Uri.parse(resource.url),
        headers: {
          if (_accessToken != null)
            'Authorization': 'Bearer $_accessToken',
          'Accept': '*/*',
        },
      );

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = response.bodyBytes;

        if (resource.size > 0 && body.length != resource.size) {
          debugPrint('⚠️ Size mismatch: expected ${resource.size}, got ${body.length}');
          return DownloadResult.error('Size mismatch: expected ${resource.size}, got ${body.length}');
        }

        final sha256 = _calculateSha256(body);
        if (sha256 != resource.sha256) {
          debugPrint('⚠️ SHA-256 mismatch: expected ${resource.sha256}, got $sha256');
          return DownloadResult.error('SHA-256 mismatch');
        }

        debugPrint('✅ Download successful: ${resource.key}');
        return DownloadResult.success(body);
      } else if (response.statusCode == 401) {
        return DownloadResult.unauthorized();
      } else if (response.statusCode == 403) {
        return DownloadResult.forbidden();
      } else if (response.statusCode == 404) {
        return DownloadResult.notFound();
      } else {
        return DownloadResult.error('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return DownloadResult.error('Network error: $e');
    }
  }

  String _calculateSha256(List<int> data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }
}

class DownloadResult {
  final bool success;
  final List<int>? data;
  final String? error;
  final DownloadStatus status;

  DownloadResult._({
    required this.success,
    this.data,
    this.error,
    required this.status,
  });

  factory DownloadResult.success(List<int> data) {
    return DownloadResult._(
      success: true,
      data: data,
      status: DownloadStatus.success,
    );
  }

  factory DownloadResult.error(String error) {
    return DownloadResult._(
      success: false,
      error: error,
      status: DownloadStatus.error,
    );
  }

  factory DownloadResult.unauthorized() {
    return DownloadResult._(
      success: false,
      error: 'Unauthorized',
      status: DownloadStatus.unauthorized,
    );
  }

  factory DownloadResult.forbidden() {
    return DownloadResult._(
      success: false,
      error: 'Forbidden',
      status: DownloadStatus.forbidden,
    );
  }

  factory DownloadResult.notFound() {
    return DownloadResult._(
      success: false,
      error: 'Not Found',
      status: DownloadStatus.notFound,
    );
  }
}

enum DownloadStatus {
  success,
  error,
  unauthorized,
  forbidden,
  notFound,
}

class ManifestResponse {
  final bool success;
  final bool notModified;
  final bool isError;
  final Map<String, dynamic>? data;
  final String? etag;
  final String? error;

  ManifestResponse._({
    required this.success,
    required this.notModified,
    required this.isError,
    this.data,
    this.etag,
    this.error,
  });

  factory ManifestResponse.success(Map<String, dynamic> data, String etag) {
    return ManifestResponse._(
      success: true,
      notModified: false,
      isError: false,
      data: data,
      etag: etag,
    );
  }

  factory ManifestResponse.notModified(String etag) {
    return ManifestResponse._(
      success: false,
      notModified: true,
      isError: false,
      etag: etag,
    );
  }

  factory ManifestResponse.error(String error) {
    return ManifestResponse._(
      success: false,
      notModified: false,
      isError: true,
      error: error,
    );
  }

  factory ManifestResponse.unauthorized() {
    return ManifestResponse._(
      success: false,
      notModified: false,
      isError: true,
      error: 'Unauthorized',
    );
  }
}