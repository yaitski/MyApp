// lib/services/language_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/manifest.dart';
import '../models/language.dart';
import '../models/resource.dart';
import 'cache_service.dart';
import 'download_service.dart';

class LanguageService {
  final CacheService _cacheService;
  final DownloadService _downloadService;

  LanguageService({
    required CacheService cacheService,
    required DownloadService downloadService,
  }) : _cacheService = cacheService,
        _downloadService = downloadService;

  Future<String> getSelectedLanguage(Manifest manifest) async {
    final savedLang = await _cacheService.loadSelectedLanguage();
    if (savedLang != null) {
      final exists = manifest.languages.any((l) => l.code == savedLang);
      if (exists) {
        return savedLang;
      }
    }

    if (manifest.detectDeviceLanguage) {
      final deviceLang = await _detectDeviceLanguage();
      final matchedLang = _matchLanguage(deviceLang, manifest.languages);
      if (matchedLang != null) {
        return matchedLang;
      }
    }

    return manifest.defaultLanguage;
  }

  Future<String> _detectDeviceLanguage() async {
    // В реальном приложении используем flutter_localizations
    return 'ru';
  }

  String? _matchLanguage(String deviceLang, List<Language> languages) {
    for (final lang in languages) {
      if (lang.locale == deviceLang) {
        return lang.code;
      }
    }

    final mainLang = deviceLang.split('-').first;
    for (final lang in languages) {
      if (lang.code == mainLang) {
        return lang.code;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> loadTranslations(
      String languageCode,
      Manifest manifest,
      ) async {
    final generation = await _cacheService.loadCacheGeneration();
    if (generation == null) {
      debugPrint('⚠️ No cache generation for language: $languageCode');
      return {};
    }

    // Находим язык в манифесте
    final language = manifest.languages.firstWhere(
          (l) => l.code == languageCode,
      orElse: () => manifest.languages.firstWhere(
            (l) => l.code == manifest.fallbackLanguage,
      ),
    );

    // Используем ID языка как ключ кэша
    final cacheKey = language.id;

    debugPrint('🔍 Looking for language: $languageCode (key: $cacheKey, gen: $generation)');

    // 1. ПЫТАЕМСЯ ПРОЧИТАТЬ ИЗ КЭША
    final cachedData = await _cacheService.readResourceFile(
      cacheKey,
      generation,
    );

    if (cachedData != null) {
      try {
        final json = jsonDecode(utf8.decode(cachedData));
        if (json is Map<String, dynamic>) {
          debugPrint('✅ Loaded language from cache: $languageCode (${json.length} keys)');
          return json;
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing cached language $languageCode: $e');
      }
    }

    // 2. ЕСЛИ НЕТ В КЭШЕ - СКАЧИВАЕМ
    debugPrint('📥 Language $languageCode not in cache, downloading...');

    try {
      final resource = Resource.fromJson(language.metadata, 'language');
      final downloadResult = await _downloadService.downloadResource(resource);

      if (downloadResult.success && downloadResult.data != null) {
        // Сохраняем в кэш
        await _cacheService.writeResourceFile(
          cacheKey,
          generation,
          downloadResult.data!,
        );

        try {
          final json = jsonDecode(utf8.decode(downloadResult.data!));
          if (json is Map<String, dynamic>) {
            debugPrint('✅ Downloaded and cached language: $languageCode (${json.length} keys)');
            return json;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing downloaded language $languageCode: $e');
        }
      } else {
        debugPrint('❌ Download failed for $languageCode: ${downloadResult.error}');
      }
    } catch (e) {
      debugPrint('❌ Error downloading language $languageCode: $e');
    }

    // 3. ЕСЛИ НЕ УДАЛОСЬ - ПРОБУЕМ FALLBACK
    if (languageCode != manifest.fallbackLanguage) {
      debugPrint('🔄 Trying fallback language: ${manifest.fallbackLanguage}');
      final fallbackTranslations = await loadTranslations(
        manifest.fallbackLanguage,
        manifest,
      );
      if (fallbackTranslations.isNotEmpty) {
        debugPrint('✅ Using fallback language: ${manifest.fallbackLanguage}');
        return fallbackTranslations;
      }
    }

    debugPrint('❌ Failed to load language: $languageCode');
    return {};
  }

  String? getTranslation(
      String key,
      Map<String, dynamic> translations,
      Map<String, dynamic> fallbackTranslations,
      String? fallbackText,
      ) {
    var value = _getNestedValue(translations, key);
    if (value != null) {
      return value.toString();
    }

    value = _getNestedValue(fallbackTranslations, key);
    if (value != null) {
      return value.toString();
    }

    return fallbackText ?? key;
  }

  dynamic _getNestedValue(Map<String, dynamic> map, String path) {
    final parts = path.split('.');
    dynamic current = map;

    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  Future<void> saveSelectedLanguage(String languageCode) async {
    await _cacheService.saveSelectedLanguage(languageCode);
  }
}