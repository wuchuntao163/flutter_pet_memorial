class WidgetDefinition {
  const WidgetDefinition({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    required this.config,
    required this.template,
    required this.rowSpan,
    required this.columnSpan,
    this.defaultBackground = '',
    this.options = const {},
  });

  final int id;
  final String title;
  final String image;
  final int type;
  final List<String> config;
  final int template;
  final int rowSpan;
  final int columnSpan;
  final String defaultBackground;
  final Map<String, String> options;

  bool get isIsland => type == 2;

  String optionLabel(String key) =>
      options[key]?.trim().isNotEmpty == true ? options[key]!.trim() : key;

  factory WidgetDefinition.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> options = const {},
  }) {
    return WidgetDefinition(
      id: _asInt(json['id']),
      title: '${json['title'] ?? ''}'.trim(),
      image: '${json['image'] ?? ''}'.trim(),
      type: _asInt(json['type'], fallback: 1),
      config: _asStringList(json['config']),
      template: _asInt(json['template']),
      rowSpan: _asInt(json['widget_row'], fallback: 1).clamp(1, 20),
      columnSpan: _asInt(json['widget_column'], fallback: 1).clamp(1, 3),
      defaultBackground: '${json['default_bg'] ?? ''}'.trim(),
      options: options,
    );
  }

  WidgetDefinition copyWithDetail(
    Map<String, dynamic> info,
    Map<String, String> detailOptions,
  ) {
    final parsed = WidgetDefinition.fromJson(info, options: detailOptions);
    return WidgetDefinition(
      id: parsed.id == 0 ? id : parsed.id,
      title: parsed.title.isEmpty ? title : parsed.title,
      image: parsed.image.isEmpty ? image : parsed.image,
      type: parsed.type,
      config: parsed.config.isEmpty ? config : parsed.config,
      template: parsed.template == 0 ? template : parsed.template,
      rowSpan: parsed.rowSpan,
      columnSpan: parsed.columnSpan,
      defaultBackground: parsed.defaultBackground,
      options: detailOptions,
    );
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = '$value'.trim();
    if (text.isEmpty) return const [];
    return text
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
