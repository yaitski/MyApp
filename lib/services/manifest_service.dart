import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manifest.dart';

class ManifestService {
  static const String manifestUrl =
      'https://appmyid.open4u.ru/resources/manifest.json'; // Замените на реальный URL

  Manifest? _manifest;

  Future<Manifest> loadManifest() async {
    try {
      final response = await http.get(Uri.parse(manifestUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _manifest = Manifest.fromJson(data);
        return _manifest!;
      } else {
        throw Exception('Failed to load manifest: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading manifest: $e');
    }
  }

  Manifest? get manifest => _manifest;

  Page? getPageById(String id) {
    if (_manifest == null) return null;
    try {
      return _manifest!.pages.firstWhere((page) => page.id == id);
    } catch (e) {
      return null;
    }
  }

  Page? getEntryPage() {
    if (_manifest == null) return null;
    return getPageById(_manifest!.entryPage);
  }

  Page? getAuthPage() {
    if (_manifest == null) return null;
    return getPageById(_manifest!.authPage);
  }

  Language? getLanguage(String code) {
    if (_manifest == null) return null;
    try {
      return _manifest!.languages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  Language? getDefaultLanguage() {
    if (_manifest == null) return null;
    return getLanguage(_manifest!.defaultLanguage);
  }

  List<String> getAvailableLanguages() {
    if (_manifest == null) return [];
    return _manifest!.languages.map((lang) => lang.code).toList();
  }

  List<Style> getStylesForPage(String pageId) {
    if (_manifest == null) return [];
    final page = getPageById(pageId);
    if (page == null) return [];

    return _manifest!.styles
        .where((style) => page.styles.contains(style.id))
        .toList();
  }

  List<Script> getScriptsForPage(String pageId) {
    if (_manifest == null) return [];
    final page = getPageById(pageId);
    if (page == null) return [];

    return _manifest!.scripts
        .where((script) => page.scripts.contains(script.id))
        .toList();
  }
}