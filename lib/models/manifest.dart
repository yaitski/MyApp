class Manifest {
  final String schemaVersion;
  final String manifestVersion;
  final int cacheGeneration;
  final String defaultLanguage;
  final String fallbackLanguage;
  final String languageStorageKey;
  final bool detectDeviceLanguage;
  final String generatedAt;
  final String entryPage;
  final String authPage;
  final bool deleteMissingResources;
  final List<Page> pages;
  final List<Style> styles;
  final List<Script> scripts;
  final List<Language> languages;
  final List<Navigation> navigation;

  Manifest({
    required this.schemaVersion,
    required this.manifestVersion,
    required this.cacheGeneration,
    required this.defaultLanguage,
    required this.fallbackLanguage,
    required this.languageStorageKey,
    required this.detectDeviceLanguage,
    required this.generatedAt,
    required this.entryPage,
    required this.authPage,
    required this.deleteMissingResources,
    required this.pages,
    required this.styles,
    required this.scripts,
    required this.languages,
    required this.navigation,
  });

  factory Manifest.fromJson(Map<String, dynamic> json) {
    return Manifest(
      schemaVersion: json['schema_version']?.toString() ?? '',
      manifestVersion: json['manifest_version'] ?? '',
      cacheGeneration: json['cache_generation'] ?? 1,
      defaultLanguage: json['default_language'] ?? 'ru',
      fallbackLanguage: json['fallback_language'] ?? 'ru',
      languageStorageKey: json['language_storage_key'] ?? 'app_language',
      detectDeviceLanguage: json['detect_device_language'] ?? true,
      generatedAt: json['generated_at'] ?? '',
      entryPage: json['entry_page'] ?? 'home',
      authPage: json['auth_page'] ?? 'auth',
      deleteMissingResources: json['delete_missing_resources'] ?? true,
      pages: (json['pages'] as List?)
          ?.map((e) => Page.fromJson(e))
          .toList() ??
          [],
      styles: (json['styles'] as List?)
          ?.map((e) => Style.fromJson(e))
          .toList() ??
          [],
      scripts: (json['scripts'] as List?)
          ?.map((e) => Script.fromJson(e))
          .toList() ??
          [],
      languages: (json['languages'] as List?)
          ?.map((e) => Language.fromJson(e))
          .toList() ??
          [],
      navigation: (json['navigation'] as List?)
          ?.map((e) => Navigation.fromJson(e))
          .toList() ??
          [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'manifest_version': manifestVersion,
      'cache_generation': cacheGeneration,
      'default_language': defaultLanguage,
      'fallback_language': fallbackLanguage,
      'language_storage_key': languageStorageKey,
      'detect_device_language': detectDeviceLanguage,
      'generated_at': generatedAt,
      'entry_page': entryPage,
      'auth_page': authPage,
      'delete_missing_resources': deleteMissingResources,
      'pages': pages.map((e) => e.toJson()).toList(),
      'styles': styles.map((e) => e.toJson()).toList(),
      'scripts': scripts.map((e) => e.toJson()).toList(),
      'languages': languages.map((e) => e.toJson()).toList(),
      'navigation': navigation.map((e) => e.toJson()).toList(),
    };
  }
}

class Page {
  final String id;
  final String type;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String lastModified;
  final bool preload;
  final bool required;
  final String title;
  final String titleKey;
  final String route;
  final bool requiresAuth;
  final List<String> styles;
  final List<String> scripts;
  final String contentType;

  Page({
    required this.id,
    required this.type,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.lastModified,
    required this.preload,
    required this.required,
    required this.title,
    required this.titleKey,
    required this.route,
    required this.requiresAuth,
    required this.styles,
    required this.scripts,
    required this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'revision': revision,
      'sha256': sha256,
      'size': size,
      'last_modified': lastModified,
      'preload': preload,
      'required': required,
      'title': title,
      'title_key': titleKey,
      'route': route,
      'requires_auth': requiresAuth,
      'styles': styles,
      'scripts': scripts,
      'content_type': contentType,
    };
  }

  factory Page.fromJson(Map<String, dynamic> json) {
    return Page(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      revision: json['revision'] ?? '',
      sha256: json['sha256'] ?? '',
      size: json['size'] ?? 0,
      lastModified: json['last_modified'] ?? '',
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      title: json['title'] ?? '',
      titleKey: json['title_key'] ?? '',
      route: json['route'] ?? '',
      requiresAuth: json['requires_auth'] ?? false,
      styles: (json['styles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      scripts: (json['scripts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contentType: json['content_type'] ?? '',
    );
  }
}

class Style {
  final String id;
  final String type;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String lastModified;
  final bool preload;
  final bool required;
  final String media;
  final String contentType;

  Style({
    required this.id,
    required this.type,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.lastModified,
    required this.preload,
    required this.required,
    required this.media,
    required this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'revision': revision,
      'sha256': sha256,
      'size': size,
      'last_modified': lastModified,
      'preload': preload,
      'required': required,
      'media': media,
      'content_type': contentType,
    };
  }

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      revision: json['revision'] ?? '',
      sha256: json['sha256'] ?? '',
      size: json['size'] ?? 0,
      lastModified: json['last_modified'] ?? '',
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      media: json['media'] ?? '',
      contentType: json['content_type'] ?? '',
    );
  }
}

class Script {
  final String id;
  final String type;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String lastModified;
  final bool preload;
  final bool required;
  final int loadOrder;
  final bool defer;
  final bool module;
  final String contentType;

  Script({
    required this.id,
    required this.type,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.lastModified,
    required this.preload,
    required this.required,
    required this.loadOrder,
    required this.defer,
    required this.module,
    required this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'revision': revision,
      'sha256': sha256,
      'size': size,
      'last_modified': lastModified,
      'preload': preload,
      'required': required,
      'load_order': loadOrder,
      'defer': defer,
      'module': module,
      'content_type': contentType,
    };
  }

  factory Script.fromJson(Map<String, dynamic> json) {
    return Script(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      revision: json['revision'] ?? '',
      sha256: json['sha256'] ?? '',
      size: json['size'] ?? 0,
      lastModified: json['last_modified'] ?? '',
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      loadOrder: json['load_order'] ?? 0,
      defer: json['defer'] ?? false,
      module: json['module'] ?? false,
      contentType: json['content_type'] ?? '',
    );
  }
}

class Language {
  final String id;
  final String type;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String lastModified;
  final bool preload;
  final bool required;
  final String code;
  final String locale;
  final String name;
  final String nativeName;
  final String direction;
  final String format;
  final String contentType;

  Language({
    required this.id,
    required this.type,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.lastModified,
    required this.preload,
    required this.required,
    required this.code,
    required this.locale,
    required this.name,
    required this.nativeName,
    required this.direction,
    required this.format,
    required this.contentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'revision': revision,
      'sha256': sha256,
      'size': size,
      'last_modified': lastModified,
      'preload': preload,
      'required': required,
      'code': code,
      'locale': locale,
      'name': name,
      'native_name': nativeName,
      'direction': direction,
      'format': format,
      'content_type': contentType,
    };
  }

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      revision: json['revision'] ?? '',
      sha256: json['sha256'] ?? '',
      size: json['size'] ?? 0,
      lastModified: json['last_modified'] ?? '',
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      code: json['code'] ?? '',
      locale: json['locale'] ?? '',
      name: json['name'] ?? '',
      nativeName: json['native_name'] ?? '',
      direction: json['direction'] ?? 'ltr',
      format: json['format'] ?? '',
      contentType: json['content_type'] ?? '',
    );
  }
}

class Navigation {
  final String id;
  final String title;
  final String titleKey;
  final List<String> items;

  Navigation({
    required this.id,
    required this.title,
    required this.titleKey,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_key': titleKey,
      'items': items,
    };
  }

  factory Navigation.fromJson(Map<String, dynamic> json) {
    return Navigation(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      titleKey: json['title_key'] ?? '',
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

