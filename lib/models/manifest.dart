import 'page.dart';
import 'style.dart';
import 'script.dart';
import 'language.dart';
import 'navigation.dart';

class Manifest {
  final int schemaVersion;
  final String? baseUrl;
  final String entryPage;
  final String defaultLanguage;
  final String fallbackLanguage;
  final String languageStorageKey;
  final bool detectDeviceLanguage;
  final int cacheGeneration;
  final bool deleteMissingResources;
  final List<Page> pages;
  final List<Style> styles;
  final List<Script> scripts;
  final List<Language> languages;
  final List<NavigationGroup> navigation;
  final Map<String, dynamic> metadata;

  Manifest({
    required this.schemaVersion,
    this.baseUrl,
    required this.entryPage,
    required this.defaultLanguage,
    required this.fallbackLanguage,
    required this.languageStorageKey,
    required this.detectDeviceLanguage,
    required this.cacheGeneration,
    required this.deleteMissingResources,
    required this.pages,
    required this.styles,
    required this.scripts,
    required this.languages,
    required this.navigation,
    required this.metadata,
  });

  factory Manifest.fromJson(Map<String, dynamic> json) {
    return Manifest(
      schemaVersion: json['schema_version'] as int,
      baseUrl: json['base_url'] as String?,
      entryPage: json['entry_page'] as String,
      defaultLanguage: json['default_language'] as String,
      fallbackLanguage: json['fallback_language'] as String,
      languageStorageKey: json['language_storage_key'] as String? ?? 'miniapp_language',
      detectDeviceLanguage: json['detect_device_language'] ?? true,
      cacheGeneration: json['cache_generation'] as int,
      deleteMissingResources: json['delete_missing_resources'] ?? false,
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => Page.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      styles: (json['styles'] as List<dynamic>?)
          ?.map((e) => Style.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      scripts: (json['scripts'] as List<dynamic>?)
          ?.map((e) => Script.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      languages: (json['languages'] as List<dynamic>?)
          ?.map((e) => Language.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      navigation: (json['navigation'] as List<dynamic>?)
          ?.map((e) => NavigationGroup.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      metadata: json,
    );
  }
}