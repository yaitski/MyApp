class Resource {
  final String id;
  final String type;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final bool preload;
  final bool required;
  final Map<String, dynamic> metadata;

  Resource({
    required this.id,
    required this.type,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.preload,
    required this.required,
    required this.metadata,
  });

  factory Resource.fromJson(Map<String, dynamic> json, String type) {
    return Resource(
      id: json['id'] as String,
      type: type,
      url: json['url'] as String,
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      metadata: json,
    );
  }

  String get key => '$type:$id';
}