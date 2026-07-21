import 'manifest.dart';

class AppState {
  final String? manifestEtag;
  final Manifest? manifest;
  final int cacheGeneration;
  final String selectedLanguage;
  final Map<String, ResourceInfo> resourceIndex;

  AppState({
    this.manifestEtag,
    this.manifest,
    this.cacheGeneration = 1,
    this.selectedLanguage = 'ru',
    this.resourceIndex = const {},
  });

  AppState copyWith({
    String? manifestEtag,
    Manifest? manifest,
    int? cacheGeneration,
    String? selectedLanguage,
    Map<String, ResourceInfo>? resourceIndex,
  }) {
    return AppState(
      manifestEtag: manifestEtag ?? this.manifestEtag,
      manifest: manifest ?? this.manifest,
      cacheGeneration: cacheGeneration ?? this.cacheGeneration,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      resourceIndex: resourceIndex ?? this.resourceIndex,
    );
  }

  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      manifestEtag: json['manifest_etag'],
      manifest: json['manifest_json'] != null
          ? Manifest.fromJson(json['manifest_json'])
          : null,
      cacheGeneration: json['cache_generation'] ?? 1,
      selectedLanguage: json['selected_language'] ?? 'ru',
      resourceIndex: (json['resource_index'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, ResourceInfo.fromJson(value)),
      ) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manifest_etag': manifestEtag,
      'manifest_json': manifest?.toJson(),
      'cache_generation': cacheGeneration,
      'selected_language': selectedLanguage,
      'resource_index': resourceIndex.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class ResourceInfo {
  final String type;
  final String id;
  final String revision;
  final String sha256;
  final int size;
  final String path;

  ResourceInfo({
    required this.type,
    required this.id,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.path,
  });

  factory ResourceInfo.fromJson(Map<String, dynamic> json) {
    return ResourceInfo(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      revision: json['revision'] ?? '',
      sha256: json['sha256'] ?? '',
      size: json['size'] ?? 0,
      path: json['path'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'revision': revision,
      'sha256': sha256,
      'size': size,
      'path': path,
    };
  }

  String get key => '$type:$id';
}