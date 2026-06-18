import 'package:flutter/foundation.dart';

/// 分段打印长日志，避免 Android logcat / 终端单条长度截断
void debugPrintLong(String tag, Object? message) {
  if (!kDebugMode) return;
  final text = message.toString();
  const chunkSize = 600;
  if (text.length <= chunkSize) {
    debugPrint('$tag $text');
    return;
  }
  final total = (text.length / chunkSize).ceil();
  for (var i = 0; i < text.length; i += chunkSize) {
    final end = i + chunkSize > text.length ? text.length : i + chunkSize;
    debugPrint(
      '$tag (${i ~/ chunkSize + 1}/$total): ${text.substring(i, end)}',
    );
  }
}
