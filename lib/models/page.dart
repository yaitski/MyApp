class Page {
  final String id;
  final String title;
  final String? titleKey;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String? route;
  final bool requiresAuth;
  final bool preload;
  final bool required;
  final List<String> styles;
  final List<String> scripts;
  final Map<String, dynamic> metadata;

  Page({
    required this.id,
    required this.title,
    this.titleKey,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    this.route,
    required this.requiresAuth,
    required this.preload,
    required this.required,
    required this.styles,
    required this.scripts,
    required this.metadata,
  });

  factory Page.fromJson(Map<String, dynamic> json) {
    return Page(
      id: json['id'] as String,
      title: json['title'] as String,
      titleKey: json['title_key'] as String?,
      url: json['url'] as String,
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
      route: json['route'] as String?,
      requiresAuth: json['requires_auth'] ?? false,
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      styles: (json['styles'] as List<dynamic>?)?.cast<String>() ?? [],
      scripts: (json['scripts'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json,
    );
  }

  String get key => 'page:$id';
}