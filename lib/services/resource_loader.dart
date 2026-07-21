import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/manifest.dart' as manifest_models;
import '../models/resource_models.dart';

class ResourceLoader {
  String? _currentGenerationPath;

  Future<void> createNewGeneration(int generation) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final generationDir = Directory(
        path.join(baseDir.path, 'generation_$generation')
    );
    if (!await generationDir.exists()) {
      await generationDir.create(recursive: true);
    }
    _currentGenerationPath = generationDir.path;
  }

  // Исправлено: используем ResourceLoadItem и ResourceLoadResult
  Future<List<ResourceLoadResult>> loadResources(
      List<ResourceLoadItem> items,
      int generation,
      ) async {
    final results = <ResourceLoadResult>[];

    final baseDir = await getApplicationDocumentsDirectory();
    final generationDir = Directory(
        path.join(baseDir.path, 'generation_$generation')
    );
    if (!await generationDir.exists()) {
      await generationDir.create(recursive: true);
    }

    for (var item in items) {
      try {
        final result = await _downloadResource(item, generationDir.path);
        results.add(result);
      } catch (e) {
        results.add(ResourceLoadResult(
          type: item.type,
          id: item.id,
          revision: item.revision,
          sha256: item.sha256,
          size: item.size,
          success: false,
          localPath: '',
          error: e.toString(),
          isRequired: item.isRequired,
        ));
      }
    }

    return results;
  }

  Future<ResourceLoadResult> _downloadResource(
      ResourceLoadItem item,
      String generationPath,
      ) async {
    final fileName = '${item.type}_${item.id}_${item.revision}';
    final localPath = path.join(generationPath, fileName);
    final file = File(localPath);

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final sha256 = _calculateSha256(bytes);

      if (sha256 == item.sha256) {
        return ResourceLoadResult(
          type: item.type,
          id: item.id,
          revision: item.revision,
          sha256: item.sha256,
          size: item.size,
          success: true,
          localPath: localPath,
          isRequired: item.isRequired,
        );
      }
    }

    final response = await http.get(Uri.parse(item.url));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final bytes = response.bodyBytes;

    if (bytes.length != item.size) {
      throw Exception('Size mismatch: ${bytes.length} != ${item.size}');
    }

    final sha256 = _calculateSha256(bytes);

    if (sha256 != item.sha256) {
      throw Exception('SHA256 mismatch');
    }

    final tempFile = File('$localPath.tmp');
    await tempFile.writeAsBytes(bytes);
    await tempFile.rename(localPath);

    return ResourceLoadResult(
      type: item.type,
      id: item.id,
      revision: item.revision,
      sha256: item.sha256,
      size: bytes.length,
      success: true,
      localPath: localPath,
      isRequired: item.isRequired,
    );
  }

  String _calculateSha256(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> deleteResource(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteGeneration(int generation) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final generationDir = Directory(
        path.join(baseDir.path, 'generation_$generation')
    );
    if (await generationDir.exists()) {
      await generationDir.delete(recursive: true);
    }
  }

  // Методы для загрузки ресурсов
  Future<String> loadPageHtml(manifest_models.Page page, int generation) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final filePath = path.join(
      baseDir.path,
      'generation_$generation',
      'page_${page.id}_${page.revision}',
    );
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsString();
    }

    final response = await http.get(Uri.parse(page.url));
    if (response.statusCode == 200) {
      return response.body;
    }

    throw Exception('Failed to load page: ${page.id}');
  }

  Future<String> loadCss(manifest_models.Style style, int generation) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final filePath = path.join(
      baseDir.path,
      'generation_$generation',
      'style_${style.id}_${style.revision}',
    );
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsString();
    }

    final response = await http.get(Uri.parse(style.url));
    if (response.statusCode == 200) {
      return response.body;
    }

    throw Exception('Failed to load CSS: ${style.id}');
  }

  Future<String> loadJs(manifest_models.Script script, int generation) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final filePath = path.join(
      baseDir.path,
      'generation_$generation',
      'script_${script.id}_${script.revision}',
    );
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsString();
    }

    final response = await http.get(Uri.parse(script.url));
    if (response.statusCode == 200) {
      return response.body;
    }

    throw Exception('Failed to load JS: ${script.id}');
  }

  Future<Map<String, dynamic>> loadLanguage(manifest_models.Language language, int generation) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final filePath = path.join(
      baseDir.path,
      'generation_$generation',
      'language_${language.id}_${language.revision}',
    );
    final file = File(filePath);

    String jsonString;
    if (await file.exists()) {
      jsonString = await file.readAsString();
    } else {
      final response = await http.get(Uri.parse(language.url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load language: ${language.id}');
      }
      jsonString = response.body;
    }

    return json.decode(jsonString);
  }
}