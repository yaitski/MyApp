import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/manifest.dart';
import '../models/resource.dart';
import '../models/page.dart';
import '../models/style.dart';
import '../models/script.dart';
import '../models/language.dart';

class CacheService {
  static const String manifestETagKey = 'manifest_etag';
  static const String manifestJsonKey = 'manifest_json';
  static const String cacheGenerationKey = 'cache_generation';
  static const String selectedLanguageKey = 'selected_language';
  static const String resourceIndexKey = 'resource_index';

  final Map<String, dynamic> _preferences = {};
  String? _activeCachePath;

  Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _activeCachePath = '${appDocDir.path}/miniapp-cache';
    await _ensureCacheDirectory();
  }

  Future<void> _ensureCacheDirectory() async {
    final dir = Directory(_activeCachePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<String> getGenerationPath(int generation) async {
    return '$_activeCachePath/generation-$generation';
  }

  Future<void> saveManifest(String etag, Manifest manifest, int generation) async {
    await _saveString(manifestETagKey, etag);
    await _saveString(manifestJsonKey, jsonEncode(manifest.metadata));
    await _saveInt(cacheGenerationKey, generation);
  }

  Future<Manifest?> loadManifest() async {
    try {
      final jsonStr = await _getString(manifestJsonKey);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr);
        return Manifest.fromJson(json as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading manifest: $e');
    }
    return null;
  }

  Future<String?> loadManifestETag() async {
    return await _getString(manifestETagKey);
  }

  Future<int?> loadCacheGeneration() async {
    return await _getInt(cacheGenerationKey);
  }

  Future<void> saveSelectedLanguage(String language) async {
    await _saveString(selectedLanguageKey, language);
  }

  Future<String?> loadSelectedLanguage() async {
    return await _getString(selectedLanguageKey);
  }

  Future<void> saveResourceIndex(Map<String, ResourceInfo> index) async {
    final json = index.map((key, value) => MapEntry(key, value.toJson()));
    await _saveString(resourceIndexKey, jsonEncode(json));
  }

  Future<Map<String, ResourceInfo>> loadResourceIndex() async {
    try {
      final jsonStr = await _getString(resourceIndexKey);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return json.map((key, value) =>
            MapEntry(key, ResourceInfo.fromJson(value as Map<String, dynamic>))
        );
      }
    } catch (e) {
      debugPrint('Error loading resource index: $e');
    }
    return {};
  }

  Future<File> getResourceFile(String key, int generation) async {
    final path = await getGenerationPath(generation);
    final filePath = '$path/${key.replaceAll(':', '_')}';
    return File(filePath);
  }

  Future<void> writeResourceFile(
      String key,
      int generation,
      List<int> data,
      ) async {
    final path = await getGenerationPath(generation);
    await Directory(path).create(recursive: true);
    final file = await getResourceFile(key, generation);
    await file.writeAsBytes(data);
  }

  Future<List<int>?> readResourceFile(String key, int generation) async {
    try {
      final file = await getResourceFile(key, generation);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading resource file: $e');
    }
    return null;
  }

  Future<void> deleteResourceFile(String key, int generation) async {
    try {
      final file = await getResourceFile(key, generation);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting resource file: $e');
    }
  }

  Future<void> deleteGeneration(int generation) async {
    try {
      final path = await getGenerationPath(generation);
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting generation: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = Directory(_activeCachePath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await _ensureCacheDirectory();
      await _clearPreferences();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // Вспомогательные методы для работы с локальным хранилищем
  Future<void> _saveString(String key, String value) async {
    _preferences[key] = value;
  }

  Future<String?> _getString(String key) async {
    return _preferences[key] as String?;
  }

  Future<void> _saveInt(String key, int value) async {
    _preferences[key] = value;
  }

  Future<int?> _getInt(String key) async {
    return _preferences[key] as int?;
  }

  Future<void> _clearPreferences() async {
    _preferences.clear();
  }
}

class ResourceInfo {
  final String revision;
  final String sha256;
  final String path;

  ResourceInfo({
    required this.revision,
    required this.sha256,
    required this.path,
  });

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'sha256': sha256,
    'path': path,
  };

  factory ResourceInfo.fromJson(Map<String, dynamic> json) {
    return ResourceInfo(
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      path: json['path'] as String,
    );
  }
}