class Style {
  final String id;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final String media;
  final bool preload;
  final bool required;
  final Map<String, dynamic> metadata;

  Style({
    required this.id,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.media,
    required this.preload,
    required this.required,
    required this.metadata,
  });

  factory Style.fromJson(Map<String, dynamic> json) {
    return Style(
      id: json['id'] as String,
      url: json['url'] as String,
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
      media: json['media'] ?? 'all',
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      metadata: json,
    );
  }

  String get key => 'style:$id';
}