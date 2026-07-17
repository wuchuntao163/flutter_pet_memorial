class SavedWidget {
  const SavedWidget({
    required this.widgetId,
    required this.title,
    required this.image,
    required this.template,
    required this.savedAt,
  });

  final int widgetId;
  final String title;
  final String image;
  final int template;
  final DateTime savedAt;

  factory SavedWidget.fromJson(Map<String, dynamic> json) => SavedWidget(
    widgetId: int.tryParse('${json['widget_id'] ?? ''}') ?? 0,
    title: '${json['title'] ?? ''}'.trim(),
    image: '${json['image'] ?? ''}'.trim(),
    template: int.tryParse('${json['template'] ?? ''}') ?? 0,
    savedAt: DateTime.tryParse('${json['saved_at'] ?? ''}') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'widget_id': widgetId,
    'title': title,
    'image': image,
    'template': template,
    'saved_at': savedAt.toIso8601String(),
  };
}
