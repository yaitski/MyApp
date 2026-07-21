import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';
import '../models/manifest.dart';

class StorageService {
  static const String _appStateKey = 'app_state';
  static const String _manifestEtagKey = 'manifest_etag';
  static const String _manifestJsonKey = 'manifest_json';
  static const String _cacheGenerationKey = 'cache_generation';
  static const String _selectedLanguageKey = 'selected_language';
  static const String _resourceIndexKey = 'resource_index';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<AppState> loadAppState() async {
    try {
      final appStateJson = _prefs.getString(_appStateKey);
      if (appStateJson != null) {
        final Map<String, dynamic> data = json.decode(appStateJson);
        return AppState.fromJson(data);
      }
    } catch (e) {
      print('Error loading app state: $e');
    }
    return AppState();
  }

  Future<void> saveAppState(AppState state) async {
    try {
      await _prefs.setString(_appStateKey, json.encode(state.toJson()));
    } catch (e) {
      print('Error saving app state: $e');
    }
  }

  Future<void> saveManifestEtag(String etag) async {
    await _prefs.setString(_manifestEtagKey, etag);
  }

  Future<void> saveManifestJson(Manifest manifest) async {
    await _prefs.setString(_manifestJsonKey, json.encode(manifest.toJson()));
  }

  Future<void> saveCacheGeneration(int generation) async {
    await _prefs.setInt(_cacheGenerationKey, generation);
  }

  Future<void> saveSelectedLanguage(String language) async {
    await _prefs.setString(_selectedLanguageKey, language);
  }

  Future<void> saveResourceIndex(Map<String, ResourceInfo> index) async {
    final Map<String, dynamic> jsonMap = index.map(
          (key, value) => MapEntry(key, value.toJson()),
    );
    await _prefs.setString(_resourceIndexKey, json.encode(jsonMap));
  }

  String? getManifestEtag() => _prefs.getString(_manifestEtagKey);
  String? getManifestJson() => _prefs.getString(_manifestJsonKey);
  int getCacheGeneration() => _prefs.getInt(_cacheGenerationKey) ?? 1;
  String getSelectedLanguage() => _prefs.getString(_selectedLanguageKey) ?? 'ru';

  Map<String, ResourceInfo> getResourceIndex() {
    final jsonString = _prefs.getString(_resourceIndexKey);
    if (jsonString == null) return {};
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      return data.map(
            (key, value) => MapEntry(key, ResourceInfo.fromJson(value)),
      );
    } catch (e) {
      return {};
    }
  }

  Future<void> clearAppState() async {
    await _prefs.remove(_appStateKey);
    await _prefs.remove(_manifestEtagKey);
    await _prefs.remove(_manifestJsonKey);
    await _prefs.remove(_cacheGenerationKey);
    await _prefs.remove(_selectedLanguageKey);
    await _prefs.remove(_resourceIndexKey);
  }
}