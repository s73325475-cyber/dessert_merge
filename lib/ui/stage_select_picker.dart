import 'package:flutter/material.dart';

import '../game/config.dart';
import 'app_ui.dart';

/// 클리어한 스테이지 중 선택 (보스 파밍 포함)
Future<int?> showStageSelectPicker(
  BuildContext context, {
  required int maxStage,
  int clearedThrough = 0,
  int? initialStage,
  String title = '스테이지 선택',
  String? subtitle,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _StageSelectDialog(
      maxStage: maxStage,
      clearedThrough: clearedThrough,
      initialStage: initialStage,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _StageSelectDialog extends StatefulWidget {
  const _StageSelectDialog({
    required this.maxStage,
    required this.clearedThrough,
    this.initialStage,
    required this.title,
    this.subtitle,
  });

  final int maxStage;
  final int clearedThrough;
  final int? initialStage;
  final String title;
  final String? subtitle;

  @override
  State<_StageSelectDialog> createState() => _StageSelectDialogState();
}

class _StageSelectDialogState extends State<_StageSelectDialog> {
  static const _columns = 5;
  static const _cellGap = 6.0;
  static const _rowGap = 8.0;
  static const _chipHeight = 44.0;

  int? _selected;

  bool _isBoss(int s) => s % GameConfig.bossEvery == 0;

  int get _max => widget.maxStage.clamp(1, 999);

  int get _clearedThrough => widget.clearedThrough.clamp(0, _max);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStage;
    if (initial != null) {
      _selected = initial.clamp(1, _max);
    }
  }

  void _pick(int s) => setState(() => _selected = s);

  Widget _buildGrid() {
    final rows = <Widget>[];
    for (var start = 1; start <= _max; start += _columns) {
      final cells = <Widget>[];
      for (var col = 0; col < _columns; col++) {
        final stage = start + col;
        cells.add(
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: col == 0 ? 0 : _cellGap / 2,
                right: col == _columns - 1 ? 0 : _cellGap / 2,
              ),
              child: stage <= _max
                  ? _StageChip(
                      label: _isBoss(stage) ? '👹 $stage' : '$stage',
                      selected: _selected == stage,
                      boss: _isBoss(stage),
                      cleared: stage <= _clearedThrough,
                      height: _chipHeight,
                      onTap: () => _pick(stage),
                    )
                  : SizedBox(height: _chipHeight),
            ),
          ),
        );
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
      if (start + _columns <= _max) {
        rows.add(const SizedBox(height: _rowGap));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff2c1f43),
      title: Text(widget.title, style: AppUi.modalTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: AppUi.dim.copyWith(fontSize: 13, color: Colors.white54),
                ),
              if (widget.subtitle != null) const SizedBox(height: 10),
              Text(
                '회색 = 클리어 · 👹 = 보스 · 보스 격파 후 같은 스테이지 반복(파밍)',
                style: AppUi.dim.copyWith(fontSize: 12, color: Colors.white38),
              ),
              const SizedBox(height: 12),
              _buildGrid(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: AppUi.button.copyWith(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text('시작', style: AppUi.button.copyWith(color: Colors.amberAccent)),
        ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.selected,
    required this.boss,
    required this.cleared,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool boss;
  final bool cleared;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0x55f5b945)
        : cleared
            ? const Color(0x66808080)
            : boss
                ? const Color(0x44ff5d5d)
                : Colors.white.withValues(alpha: 0.1);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.amberAccent
                  : cleared
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppUi.body.copyWith(
              fontSize: 13,
              color: cleared && !selected ? Colors.white70 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
