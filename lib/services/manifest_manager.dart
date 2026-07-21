import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manifest.dart';
import '../models/app_state.dart';
import '../models/resource_models.dart';
import 'storage_service.dart';
import 'resource_loader.dart';

class ManifestManager {
  static const String _manifestUrl =
      'https://appmyid.open4u.ru/manifest';

  final StorageService _storage;
  final ResourceLoader _resourceLoader;

  AppState? _currentState;
  Manifest? _activeManifest;

  ManifestManager({
    required SharedPreferences prefs,
  }) : _storage = StorageService(prefs),
        _resourceLoader = ResourceLoader();

  // 1. Загрузить локальное состояние
  Future<AppState> loadLocalState() async {
    _currentState = await _storage.loadAppState();
    if (_currentState?.manifest != null) {
      _activeManifest = _currentState!.manifest;
    }
    return _currentState!;
  }

  // 2-6. Получить манифест с сервера
  Future<Manifest> fetchManifest({String? etag}) async {
    final headers = <String, String>{};
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    final response = await http.get(
      Uri.parse(_manifestUrl),
      headers: headers,
    );

    // 4. Ответ 304 - используем локальный манифест
    if (response.statusCode == 304) {
      if (_currentState?.manifest != null) {
        return _currentState!.manifest!;
      }
      throw Exception('No local manifest available');
    }

    // 5. Ответ не 200 и не 304
    if (response.statusCode != 200) {
      if (_currentState?.manifest != null) {
        return _currentState!.manifest!;
      }
      throw Exception('Failed to load manifest: ${response.statusCode}');
    }

    // 6. Ответ 200 - разбираем новый манифест
    final newEtag = response.headers['etag'];
    final Map<String, dynamic> data = json.decode(response.body);

    // Проверяем schema_version
    if (data['schema_version'] != 1) {
      throw Exception('Unsupported schema version');
    }

    final newManifest = Manifest.fromJson(data);

    // Сохраняем ETag
    if (newEtag != null) {
      await _storage.saveManifestEtag(newEtag);
    }

    return newManifest;
  }

  // Основной метод синхронизации
  Future<Manifest> syncManifest() async {
    try {
      // 1. Загружаем локальное состояние
      await loadLocalState();

      final currentEtag = _currentState?.manifestEtag;

      // 2-6. Получаем манифест
      Manifest newManifest;
      try {
        newManifest = await fetchManifest(etag: currentEtag);
      } catch (e) {
        // Если ошибка и есть локальный манифест - используем его
        if (_currentState?.manifest != null) {
          return _currentState!.manifest!;
        }
        rethrow;
      }

      // Если манифест не изменился
      if (newManifest.manifestVersion == _currentState?.manifest?.manifestVersion) {
        _activeManifest = newManifest;
        return newManifest;
      }

      // 7-8. Проверяем cache_generation
      final oldGeneration = _currentState?.cacheGeneration ?? 0;
      final newGeneration = newManifest.cacheGeneration;

      Map<String, ResourceInfo> newResourceIndex = {};

      if (newGeneration != oldGeneration) {
        // 8. Создаем новый пустой каталог поколения
        await _resourceLoader.createNewGeneration(newGeneration);
        // Все ресурсы считаем отсутствующими
      } else {
        // 9. Сравниваем ресурсы
        newResourceIndex = _currentState?.resourceIndex ?? {};
      }

      // 10. Удаляем отсутствующие ресурсы
      if (newManifest.deleteMissingResources) {
        await _removeMissingResources(newManifest, newResourceIndex);
      }

      // 11. Определяем выбранный язык
      final selectedLanguage = await _determineLanguage(newManifest);

      // 12-13. Формируем очередь и загружаем ресурсы
      final resourcesToLoad = _buildPreloadQueue(newManifest, selectedLanguage);

      // 14. Загружаем ресурсы
      final loadedResources = await _resourceLoader.loadResources(
        resourcesToLoad,
        newGeneration,
      );

      // 15. Проверяем обязательные ресурсы
      final failedRequired = loadedResources
          .where((r) => r.isRequired && !r.success)
          .toList();

      if (failedRequired.isNotEmpty) {
        // Если обязательный ресурс не загружен - отменяем
        print('Failed to load required resources: ${failedRequired.map((r) => r.id)}');
        if (_currentState?.manifest != null) {
          return _currentState!.manifest!;
        }
        throw Exception('Failed to load required resources');
      }

      // 16. Сохраняем новое состояние
      final updatedIndex = _updateResourceIndex(
        newResourceIndex,
        loadedResources,
        newGeneration,
      );

      final newState = AppState(
        manifestEtag: _currentState?.manifestEtag,
        manifest: newManifest,
        cacheGeneration: newGeneration,
        selectedLanguage: selectedLanguage,
        resourceIndex: updatedIndex,
      );

      await _storage.saveAppState(newState);
      _currentState = newState;
      _activeManifest = newManifest;

      // Удаляем старое поколение
      if (newGeneration != oldGeneration) {
        await _resourceLoader.deleteGeneration(oldGeneration);
      }

      return newManifest;
    } catch (e) {
      print('Error syncing manifest: $e');
      if (_currentState?.manifest != null) {
        return _currentState!.manifest!;
      }
      rethrow;
    }
  }

  // Удаление отсутствующих ресурсов
  Future<void> _removeMissingResources(
      Manifest newManifest,
      Map<String, ResourceInfo> currentIndex,
      ) async {
    final newResourceKeys = <String>{};

    // Собираем все ID ресурсов из нового манифеста
    for (var page in newManifest.pages) {
      newResourceKeys.add('page:${page.id}');
    }
    for (var style in newManifest.styles) {
      newResourceKeys.add('style:${style.id}');
    }
    for (var script in newManifest.scripts) {
      newResourceKeys.add('script:${script.id}');
    }
    for (var lang in newManifest.languages) {
      newResourceKeys.add('language:${lang.id}');
    }

    // Удаляем отсутствующие ресурсы
    final keysToRemove = currentIndex.keys
        .where((key) => !newResourceKeys.contains(key))
        .toList();

    for (var key in keysToRemove) {
      final resource = currentIndex[key];
      if (resource != null) {
        await _resourceLoader.deleteResource(resource.path);
        currentIndex.remove(key);
      }
    }
  }

  // Определение языка
  Future<String> _determineLanguage(Manifest manifest) async {
    // Проверяем сохраненный язык
    final savedLanguage = _storage.getSelectedLanguage();
    if (savedLanguage.isNotEmpty &&
        manifest.languages.any((l) => l.code == savedLanguage)) {
      return savedLanguage;
    }

    // Проверяем язык устройства
    if (manifest.detectDeviceLanguage) {
      // Здесь можно получить язык устройства через DeviceInfo
      // Пока возвращаем язык по умолчанию
    }

    return manifest.defaultLanguage;
  }

  // Формирование очереди предзагрузки
  List<ResourceLoadItem> _buildPreloadQueue(
      Manifest manifest,
      String selectedLanguage,
      ) {
    final queue = <ResourceLoadItem>[];

    // Добавляем preload-ресурсы
    for (var style in manifest.styles) {
      if (style.preload) {
        queue.add(ResourceLoadItem(
          type: 'style',
          id: style.id,
          url: style.url,
          revision: style.revision,
          sha256: style.sha256,
          size: style.size,
          isRequired: style.required,
        ));
      }
    }

    for (var script in manifest.scripts) {
      if (script.preload) {
        queue.add(ResourceLoadItem(
          type: 'script',
          id: script.id,
          url: script.url,
          revision: script.revision,
          sha256: script.sha256,
          size: script.size,
          isRequired: script.required,
          loadOrder: script.loadOrder,
        ));
      }
    }

    for (var page in manifest.pages) {
      if (page.preload) {
        queue.add(ResourceLoadItem(
          type: 'page',
          id: page.id,
          url: page.url,
          revision: page.revision,
          sha256: page.sha256,
          size: page.size,
          isRequired: page.required,
        ));
      }
    }

    // Добавляем выбранный языковой пакет
    final selectedLang = manifest.languages
        .firstWhere((l) => l.code == selectedLanguage);
    queue.add(ResourceLoadItem(
      type: 'language',
      id: selectedLang.id,
      url: selectedLang.url,
      revision: selectedLang.revision,
      sha256: selectedLang.sha256,
      size: selectedLang.size,
      isRequired: true,
    ));

    // Добавляем fallback языковой пакет
    if (selectedLanguage != manifest.fallbackLanguage) {
      final fallbackLang = manifest.languages
          .firstWhere((l) => l.code == manifest.fallbackLanguage);
      queue.add(ResourceLoadItem(
        type: 'language',
        id: fallbackLang.id,
        url: fallbackLang.url,
        revision: fallbackLang.revision,
        sha256: fallbackLang.sha256,
        size: fallbackLang.size,
        isRequired: false,
      ));
    }

    // Сортируем скрипты по load_order
    queue.sort((a, b) {
      if (a.type == 'script' && b.type == 'script') {
        return (a.loadOrder ?? 0).compareTo(b.loadOrder ?? 0);
      }
      return 0;
    });

    return queue;
  }

  // Обновление индекса ресурсов
  Map<String, ResourceInfo> _updateResourceIndex(
      Map<String, ResourceInfo> currentIndex,
      List<ResourceLoadResult> loadedResources,
      int generation,
      ) {
    final newIndex = Map<String, ResourceInfo>.from(currentIndex);

    for (var result in loadedResources) {
      if (result.success) {
        final key = '${result.type}:${result.id}';
        newIndex[key] = ResourceInfo(
          type: result.type,
          id: result.id,
          revision: result.revision,
          sha256: result.sha256,
          size: result.size,
          path: result.localPath,
        );
      }
    }

    return newIndex;
  }

  // Получение активного манифеста
  Manifest? getActiveManifest() => _activeManifest;

  // Получение состояния
  AppState? getCurrentState() => _currentState;

  // Получение загрузчика ресурсов (для использования в WebPageScreen)
  ResourceLoader get resourceLoader => _resourceLoader;
}