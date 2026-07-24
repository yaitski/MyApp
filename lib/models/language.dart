class Language {
  final String id;
  final String code;
  final String? locale;
  final String? name;
  final String? nativeName;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String direction;
  final String format;
  final bool required;
  final bool preload;
  final Map<String, dynamic> metadata;

  Language({
    required this.id,
    required this.code,
    this.locale,
    this.name,
    this.nativeName,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.direction,
    required this.format,
    required this.required,
    required this.preload,
    required this.metadata,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'] as String,
      code: json['code'] as String,
      locale: json['locale'] as String?,
      name: json['name'] as String?,
      nativeName: json['native_name'] as String?,
      url: json['url'] as String,
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
      direction: json['direction'] ?? 'ltr',
      format: json['format'] ?? 'nested-json-v1',
      required: json['required'] ?? false,
      preload: json['preload'] ?? false,
      metadata: json,
    );
  }

  String get key => 'language:$id';
}