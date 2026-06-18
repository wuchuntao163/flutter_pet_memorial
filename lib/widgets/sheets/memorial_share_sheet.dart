import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/memorial_share_service.dart';

/// 分享到微信 / 朋友圈 / 小红书
class MemorialShareSheet extends StatelessWidget {
  final Future<MemorialShareResult> Function(MemorialShareTarget target) onShare;

  const MemorialShareSheet({super.key, required this.onShare});

  static Future<void> show(
    BuildContext context, {
    required Future<MemorialShareResult> Function(MemorialShareTarget target)
        onShare,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MemorialShareSheet(onShare: onShare),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                tr('share.title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: MemorialShareTarget.values
                    .map(
                      (target) => _ShareChannelButton(
                        target: target,
                        onTap: () => _handleShare(context, target),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    MemorialShareTarget target,
  ) async {
    Navigator.of(context).pop();
    final result = await onShare(target);
    if (!context.mounted) return;

    if (result.success) {
      final hint = result.message;
      if (hint != null && hint.isNotEmpty) {
        showCenterTip(context, hint);
      }
    } else {
      showCenterTip(context, result.message ?? tr('share.failed'));
    }
  }
}

class _ShareChannelButton extends StatelessWidget {
  final MemorialShareTarget target;
  final VoidCallback onTap;

  const _ShareChannelButton({
    required this.target,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _channelColor(target).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _channelIcon(target),
              size: 28,
              color: _channelColor(target),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            target.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static Color _channelColor(MemorialShareTarget target) {
    switch (target) {
      case MemorialShareTarget.wechatSession:
      case MemorialShareTarget.wechatTimeline:
        return const Color(0xFF07C160);
      case MemorialShareTarget.xiaohongshu:
        return const Color(0xFFFF2442);
    }
  }

  static IconData _channelIcon(MemorialShareTarget target) {
    switch (target) {
      case MemorialShareTarget.wechatSession:
        return Icons.chat_bubble_rounded;
      case MemorialShareTarget.wechatTimeline:
        return Icons.photo_camera_front_outlined;
      case MemorialShareTarget.xiaohongshu:
        return Icons.auto_stories_outlined;
    }
  }
}
