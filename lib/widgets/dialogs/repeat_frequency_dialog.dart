import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../models/memorial_day.dart';

Future<RepeatFrequency?> showRepeatFrequencyDialog(
  BuildContext context, {
  required RepeatFrequency initial,
}) {
  return showDialog<RepeatFrequency>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => _RepeatFrequencyDialog(initial: initial),
  );
}

class _RepeatFrequencyDialog extends StatefulWidget {
  final RepeatFrequency initial;

  const _RepeatFrequencyDialog({required this.initial});

  @override
  State<_RepeatFrequencyDialog> createState() => _RepeatFrequencyDialogState();
}

class _RepeatFrequencyDialogState extends State<_RepeatFrequencyDialog> {
  late RepeatFrequency _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final options = RepeatFrequency.values;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('repeat.picker_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 22, color: AppColors.textTertiary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                children: options.map((option) {
                  final isSelected = _selected == option;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = option);
                        Navigator.of(context).pop(option);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF3F4F6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
