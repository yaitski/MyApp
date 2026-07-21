class ResourceLoadItem {
  final String type;
  final String id;
  final String url;
  final String revision;
  final String sha256;
  final int size;
  final bool isRequired;
  final int? loadOrder;

  ResourceLoadItem({
    required this.type,
    required this.id,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.size,
    this.isRequired = false,
    this.loadOrder,
  });
}

class ResourceLoadResult {
  final String type;
  final String id;
  final String revision;
  final String sha256;
  final int size;
  final bool success;
  final String localPath;
  final String? error;
  final bool isRequired;

  ResourceLoadResult({
    required this.type,
    required this.id,
    required this.revision,
    required this.sha256,
    required this.size,
    required this.success,
    required this.localPath,
    this.error,
    this.isRequired = false,
  });
}