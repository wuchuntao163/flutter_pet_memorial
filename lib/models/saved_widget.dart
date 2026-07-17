class SavedWidget {
  const SavedWidget({
    required this.widgetId,
    required this.title,
    required this.image,
    required this.template,
    required this.savedAt,
    this.settings = const {},
  });

  final int widgetId;
  final String title;
  final String image;
  final int template;
  final DateTime savedAt;
  final Map<String, dynamic> settings;

  factory SavedWidget.fromJson(Map<String, dynamic> json) => SavedWidget(
    widgetId: int.tryParse('${json['widget_id'] ?? ''}') ?? 0,
    title: '${json['title'] ?? ''}'.trim(),
    image: '${json['image'] ?? ''}'.trim(),
    template: int.tryParse('${json['template'] ?? ''}') ?? 0,
    savedAt: DateTime.tryParse('${json['saved_at'] ?? ''}') ?? DateTime.now(),
    settings: json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : const {},
  );

  Map<String, dynamic> toJson() => {
    'widget_id': widgetId,
    'title': title,
    'image': image,
    'template': template,
    'saved_at': savedAt.toIso8601String(),
    'settings': settings,
  };
}
