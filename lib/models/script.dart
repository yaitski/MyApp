class Script {
  final String id;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final int loadOrder;
  final bool defer;
  final bool module;
  final bool preload;
  final bool required;
  final Map<String, dynamic> metadata;

  Script({
    required this.id,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.loadOrder,
    required this.defer,
    required this.module,
    required this.preload,
    required this.required,
    required this.metadata,
  });

  factory Script.fromJson(Map<String, dynamic> json) {
    return Script(
      id: json['id'] as String,
      url: json['url'] as String,
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      size: json['size'] as int,
      loadOrder: json['load_order'] ?? 100,
      defer: json['defer'] ?? false,
      module: json['module'] ?? false,
      preload: json['preload'] ?? false,
      required: json['required'] ?? false,
      metadata: json,
    );
  }

  String get key => 'script:$id';
}