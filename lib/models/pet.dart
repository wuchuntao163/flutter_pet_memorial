class Pet {
  final String name;
  final String type; // 'cat' or 'dog'
  final String? avatar;
  final DateTime? birthday;
  final String? avatarUrl;

  const Pet({
    required this.name,
    required this.type,
    this.avatar,
    this.birthday,
    this.avatarUrl,
  });

  int get daysSinceBirthday {
    if (birthday == null) return 0;
    return DateTime.now().difference(birthday!).inDays;
  }
}