/// 版本号解析与比较（如 1.0.0、v1.2）
class AppVersionUtil {
  AppVersionUtil._();

  static List<int> parse(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final main = cleaned.split('+').first.split('-').first;
    if (main.isEmpty) return const [0];

    return main
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
  }

  /// 大于 0 表示 [remote] 更新；0 相等；小于 0 表示 [remote] 更旧
  static int compare(String remote, String local) {
    final remoteParts = parse(remote);
    final localParts = parse(local);
    final length = remoteParts.length > localParts.length
        ? remoteParts.length
        : localParts.length;

    for (var i = 0; i < length; i++) {
      final remoteValue = i < remoteParts.length ? remoteParts[i] : 0;
      final localValue = i < localParts.length ? localParts[i] : 0;
      if (remoteValue != localValue) {
        return remoteValue.compareTo(localValue);
      }
    }
    return 0;
  }

  static bool isRemoteNewer(String remote, String local) =>
      compare(remote, local) > 0;
}
