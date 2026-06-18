import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../l10n/tr.dart';
import '../../models/memorial_day.dart';
import 'memorial_type_info.dart';

class MemorialCard extends StatelessWidget {
  final MemorialDay memorialDay;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MemorialCard({
    super.key,
    required this.memorialDay,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  static const _cardRadius = 14.0;
  static const _daysWidth = 88.0;
  static const _scallopDiameter = 10.0;
  static const _scallopCount = 6;

  String get _typeLabel => MemorialTypeInfo.label(memorialDay);

  Color get _typeBgColor => MemorialTypeInfo.daysBackground(memorialDay);

  Color get _daysColor => MemorialTypeInfo.daysText(memorialDay);

  Color get _tagBgColor => MemorialTypeInfo.tagBackground(memorialDay);

  Color get _tagTextColor => MemorialTypeInfo.tagText(memorialDay);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentDark.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: _daysWidth,
                  color: _typeBgColor,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${memorialDay.displayDayCount}',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          height: 1,
                          color: _daysColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        tr('common.unit_day'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _daysColor,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    memorialDay.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _tagBgColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _typeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _tagTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 14,
                                  color: AppColors.textTertiary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    memorialDay.formattedDate,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textTertiary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildActionButton(
                            label: tr('common.edit'),
                            bgColor: const Color(0xFFFFF0D9),
                            textColor: const Color(0xFF785C35),
                            onTap: onEdit,
                            showPinBadge: memorialDay.isPinned,
                          ),
                          const SizedBox(height: 10),
                          _buildActionButton(
                            label: tr('common.delete'),
                            bgColor: const Color(0xFFFFE8E8),
                            textColor: AppColors.delete,
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
            _buildScallopOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScallopOverlay() {
    const radius = _scallopDiameter / 2;
    return Positioned(
      left: _daysWidth - radius,
      top: 0,
      bottom: 0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          _scallopCount,
          (_) => Container(
            width: _scallopDiameter,
            height: _scallopDiameter,
            decoration: const BoxDecoration(
              color: AppColors.bgWhite,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color bgColor,
    required Color textColor,
    VoidCallback? onTap,
    bool showPinBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: AppLayout.memorialCardActionButtonWidth,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (showPinBadge)
            Positioned(
              right: -6,
              top: -10,
              child: Image.asset(
                'assets/images/image_47.png',
                width: 16,
                height: 22,
              ),
            ),
        ],
      ),
    );
  }
}
