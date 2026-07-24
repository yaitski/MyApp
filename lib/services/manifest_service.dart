import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/manifest.dart';
import '../models/resource.dart';
import '../models/page.dart';
import '../models/style.dart';
import '../models/script.dart';
import '../models/language.dart';
import 'cache_service.dart';
import 'download_service.dart';

class ManifestService {
  final CacheService _cacheService;
  final DownloadService _downloadService;

  static const supportedSchemaVersions = [1, 2];

  ManifestService({
    required CacheService cacheService,
    required DownloadService downloadService,
  }) : _cacheService = cacheService,
        _downloadService = downloadService;

  Future<ManifestCheckResult> checkAndSyncManifest() async {
    try {
      final savedETag = await _cacheService.loadManifestETag();
      final savedManifest = await _cacheService.loadManifest();
      final savedGeneration = await _cacheService.loadCacheGeneration();
      final savedLanguage = await _cacheService.loadSelectedLanguage();

      debugPrint('🔍 Checking manifest, savedETag: $savedETag, generation: $savedGeneration');

      // Передаем язык в запрос
      final response = await _downloadService.fetchManifest(
        etag: savedETag,
        languageCode: savedLanguage,
      );

      if (response.success && response.data != null) {
        return await _processNewManifest(response.data!, response.etag!, savedManifest, savedGeneration);
      } else if (response.notModified) {
        if (savedManifest != null && savedGeneration != null) {
          return ManifestCheckResult.local(
            manifest: savedManifest,
            generation: savedGeneration,
            etag: savedETag!,
          );
        } else {
          debugPrint('⚠️ 304 but no local manifest, retrying without ETag');
          final retryResponse = await _downloadService.fetchManifest();
          if (retryResponse.success && retryResponse.data != null) {
            return await _processNewManifest(retryResponse.data!, retryResponse.etag!, null, null);
          }
        }
      } else if (response.isError) {
        if (savedManifest != null && savedGeneration != null) {
          return ManifestCheckResult.local(
            manifest: savedManifest,
            generation: savedGeneration,
            etag: savedETag!,
          );
        }
      }

      return ManifestCheckResult.error('Failed to load manifest');
    } catch (e) {
      debugPrint('❌ Error in manifest sync: $e');
      final savedManifest = await _cacheService.loadManifest();
      final savedGeneration = await _cacheService.loadCacheGeneration();
      final savedETag = await _cacheService.loadManifestETag();

      if (savedManifest != null && savedGeneration != null && savedETag != null) {
        return ManifestCheckResult.local(
          manifest: savedManifest,
          generation: savedGeneration,
          etag: savedETag,
        );
      }

      return ManifestCheckResult.error('Failed to load manifest');
    }
  }

  Future<ManifestCheckResult> _processNewManifest(
      Map<String, dynamic> manifestJson,
      String newETag,
      Manifest? savedManifest,
      int? savedGeneration,
      ) async {
    try {
      final schemaVersion = manifestJson['schema_version'] as int?;
      if (schemaVersion == null || !supportedSchemaVersions.contains(schemaVersion)) {
        return ManifestCheckResult.unsupportedSchema(
          message: 'Эта версия мобильного приложения больше не поддерживает текущий формат данных. Обновите приложение.',
        );
      }

      final newManifest = Manifest.fromJson(manifestJson);
      final newGeneration = newManifest.cacheGeneration;

      final resourcesToDownload = <Resource>[];

      if (savedGeneration == null || savedGeneration != newGeneration) {
        debugPrint('🔄 Cache generation changed: $savedGeneration -> $newGeneration');
        final newGenPath = await _cacheService.getGenerationPath(newGeneration);
        await Directory(newGenPath).create(recursive: true);

        resourcesToDownload.addAll(_getAllRequiredResources(newManifest));
      } else {
        final oldResources = _getAllResources(savedManifest!);
        final newResources = _getAllResources(newManifest);

        for (final newResource in newResources) {
          final oldResource = oldResources.firstWhere(
                (r) => r.key == newResource.key,
            orElse: () => newResource,
          );

          if (oldResource.revision != newResource.revision) {
            resourcesToDownload.add(newResource);
          }
        }

        if (newManifest.deleteMissingResources) {
          await _deleteMissingResources(oldResources, newResources, savedGeneration!);
        }
      }

      final preloadResources = resourcesToDownload
          .where((r) => r.preload || _shouldPreload(r, newManifest))
          .toList();

      final loadResult = await _downloadResources(preloadResources, newGeneration);

      if (!loadResult.success) {
        return ManifestCheckResult.error('Failed to download required resources');
      }

      await _cacheService.saveManifest(
        newETag,
        newManifest,
        newGeneration,
      );

      await _saveResourceIndex(newManifest, newGeneration);

      if (savedGeneration != null && savedGeneration != newGeneration) {
        await _cacheService.deleteGeneration(savedGeneration);
      }

      return ManifestCheckResult.updated(
        manifest: newManifest,
        generation: newGeneration,
        etag: newETag,
      );
    } catch (e) {
      debugPrint('❌ Error processing new manifest: $e');
      return ManifestCheckResult.error('Failed to process new manifest');
    }
  }

  List<Resource> _getAllRequiredResources(Manifest manifest) {
    final resources = <Resource>[];
    for (final page in manifest.pages) {
      if (page.required) {
        resources.add(Resource.fromJson(page.metadata, 'page'));
      }
    }
    for (final style in manifest.styles) {
      if (style.required) {
        resources.add(Resource.fromJson(style.metadata, 'style'));
      }
    }
    for (final script in manifest.scripts) {
      if (script.required) {
        resources.add(Resource.fromJson(script.metadata, 'script'));
      }
    }
    for (final language in manifest.languages) {
      if (language.required) {
        resources.add(Resource.fromJson(language.metadata, 'language'));
      }
    }
    return resources;
  }

  List<Resource> _getAllResources(Manifest manifest) {
    final resources = <Resource>[];
    for (final page in manifest.pages) {
      resources.add(Resource.fromJson(page.metadata, 'page'));
    }
    for (final style in manifest.styles) {
      resources.add(Resource.fromJson(style.metadata, 'style'));
    }
    for (final script in manifest.scripts) {
      resources.add(Resource.fromJson(script.metadata, 'script'));
    }
    for (final language in manifest.languages) {
      resources.add(Resource.fromJson(language.metadata, 'language'));
    }
    return resources;
  }

  bool _shouldPreload(Resource resource, Manifest manifest) {
    if (resource.type == 'language') {
      final selectedLang = manifest.defaultLanguage;
      return resource.id == selectedLang || resource.id == manifest.fallbackLanguage;
    }

    for (final page in manifest.pages) {
      if (page.preload) {
        if (page.styles.contains(resource.id) && resource.type == 'style') {
          return true;
        }
        if (page.scripts.contains(resource.id) && resource.type == 'script') {
          return true;
        }
      }
    }

    return false;
  }

  Future<DownloadBatchResult> _downloadResources(
      List<Resource> resources,
      int generation,
      ) async {
    bool allSuccess = true;
    final errors = <String>[];

    for (final resource in resources) {
      final result = await _downloadService.downloadResource(resource);

      if (result.success && result.data != null) {
        await _cacheService.writeResourceFile(
          resource.key,
          generation,
          result.data!,
        );
      } else if (resource.required) {
        allSuccess = false;
        errors.add('Failed to download ${resource.key}: ${result.error}');
        break;
      }
    }

    return DownloadBatchResult(
      success: allSuccess,
      errors: errors,
    );
  }

  Future<void> _deleteMissingResources(
      List<Resource> oldResources,
      List<Resource> newResources,
      int generation,
      ) async {
    final newKeys = newResources.map((r) => r.key).toSet();
    final oldKeys = oldResources.map((r) => r.key).toSet();
    final missingKeys = oldKeys.difference(newKeys);

    for (final key in missingKeys) {
      await _cacheService.deleteResourceFile(key, generation);
    }
  }

  Future<void> _saveResourceIndex(Manifest manifest, int generation) async {
    final index = <String, ResourceInfo>{};
    final basePath = await _cacheService.getGenerationPath(generation);

    for (final resource in _getAllResources(manifest)) {
      index[resource.key] = ResourceInfo(
        revision: resource.revision,
        sha256: resource.sha256,
        path: '$basePath/${resource.key.replaceAll(':', '_')}',
      );
    }

    await _cacheService.saveResourceIndex(index);
  }
}

class ManifestCheckResult {
  final bool success;
  final bool isLocal;
  final bool isUpdated;
  final bool isUnsupported;
  final Manifest? manifest;
  final int? generation;
  final String? etag;
  final String? error;

  ManifestCheckResult._({
    required this.success,
    required this.isLocal,
    required this.isUpdated,
    required this.isUnsupported,
    this.manifest,
    this.generation,
    this.etag,
    this.error,
  });

  factory ManifestCheckResult.local({
    required Manifest manifest,
    required int generation,
    required String etag,
  }) {
    return ManifestCheckResult._(
      success: true,
      isLocal: true,
      isUpdated: false,
      isUnsupported: false,
      manifest: manifest,
      generation: generation,
      etag: etag,
    );
  }

  factory ManifestCheckResult.updated({
    required Manifest manifest,
    required int generation,
    required String etag,
  }) {
    return ManifestCheckResult._(
      success: true,
      isLocal: false,
      isUpdated: true,
      isUnsupported: false,
      manifest: manifest,
      generation: generation,
      etag: etag,
    );
  }

  factory ManifestCheckResult.unsupportedSchema({
    required String message,
  }) {
    return ManifestCheckResult._(
      success: false,
      isLocal: false,
      isUpdated: false,
      isUnsupported: true,
      error: message,
    );
  }

  factory ManifestCheckResult.error(String error) {
    return ManifestCheckResult._(
      success: false,
      isLocal: false,
      isUpdated: false,
      isUnsupported: false,
      error: error,
    );
  }
}

class DownloadBatchResult {
  final bool success;
  final List<String> errors;

  DownloadBatchResult({
    required this.success,
    this.errors = const [],
  });
}