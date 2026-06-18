import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../data/font_style_store.dart';
import '../../models/font_style_config.dart';
import '../../models/memorial_day.dart';
import '../common/memorial_day_count_display.dart';
import 'style_picker_dialog.dart';

class NumberStyleDialog extends StatefulWidget {
  final MemorialDay memorialDay;
  final String initialStyleId;
  final ValueChanged<String>? onConfirm;

  const NumberStyleDialog({
    super.key,
    required this.memorialDay,
    this.initialStyleId = FontStyleConfig.normalStyleId,
    this.onConfirm,
  });

  @override
  State<NumberStyleDialog> createState() => _NumberStyleDialogState();
}

class _NumberStyleDialogState extends State<NumberStyleDialog> {
  late String _selectedStyleId;

  @override
  void initState() {
    super.initState();
    _selectedStyleId = widget.initialStyleId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (FontStyleStore.instance.items.isEmpty) {
        await FontStyleStore.instance.fetchList();
      }
      if (!mounted) return;
      _syncSelection();
    });
  }

  void _syncSelection() {
    final effective = FontStyleConfig.effectiveStyleId(_selectedStyleId);
    if (effective != _selectedStyleId) {
      setState(() => _selectedStyleId = effective);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FontStyleStore.instance,
      builder: (context, _) {
        return StylePickerDialog(
          title: tr('dialogs.number_picker'),
          onConfirm: () => widget.onConfirm?.call(_selectedStyleId),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    final store = FontStyleStore.instance;
    final items = FontStyleConfig.displayItems();

    if (store.isLoading && store.items.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    const crossCount = 2;
    const spacing = 8.0;
    const maxRows = 2;
    const delegate = StylePickerDialog.numberStyleGridDelegate;
    final aspectRatio = delegate.childAspectRatio;
    final rows = (items.length / crossCount).ceil();
    final visibleRows = rows > maxRows ? maxRows : rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
        final cellHeight = cellWidth / aspectRatio;
        final height = cellHeight * visibleRows + spacing * (visibleRows - 1);

        return SizedBox(
          height: height,
          child: GridView.builder(
            physics: rows > maxRows
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            gridDelegate: delegate,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final id = '${item['id']}';
              final isSelected = _selectedStyleId == id;
              final name = item['name']?.toString() ?? FontStyleConfig.labelFor(id);

              return StylePickerDialog.rectGridTile(
                isSelected: isSelected,
                onTap: () => setState(() => _selectedStyleId = id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: MemorialDayCountStylePreview(
                              memorialDay: widget.memorialDay,
                              fontStyleId: id,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.modalHeader
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
