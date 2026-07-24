class NavigationGroup {
  final String id;
  final String title;
  final String? titleKey;
  final List<String> items;
  final Map<String, dynamic> metadata;

  NavigationGroup({
    required this.id,
    required this.title,
    this.titleKey,
    required this.items,
    required this.metadata,
  });

  factory NavigationGroup.fromJson(Map<String, dynamic> json) {
    return NavigationGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      titleKey: json['title_key'] as String?,
      items: (json['items'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json,
    );
  }

  String get key => 'navigation:$id';
}