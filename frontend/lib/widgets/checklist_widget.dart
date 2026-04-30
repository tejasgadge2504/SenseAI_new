import 'package:flutter/material.dart';
import '../theme.dart';

class ChecklistWidget extends StatefulWidget {
  final List<String> items;
  final ValueChanged<List<bool>> onChanged;

  const ChecklistWidget({
    super.key,
    required this.items,
    required this.onChanged,
  });

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  late List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.items.length, false);
  }

  @override
  void didUpdateWidget(ChecklistWidget old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      _checked = List.filled(widget.items.length, false);
    }
  }

  int get _checkedCount => _checked.where((v) => v).length;
  bool get halfComplete =>
      _checkedCount >= (widget.items.length / 2).ceil();

  @override
  Widget build(BuildContext context) {
    final progress = widget.items.isEmpty
        ? 0.0
        : _checkedCount / widget.items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(
                    halfComplete
                        ? AppColors.midGreen
                        : AppColors.amber,
                  ),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$_checkedCount/${widget.items.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: halfComplete ? AppColors.midGreen : AppColors.amber,
              ),
            ),
          ],
        ),
        if (!halfComplete && widget.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tick at least ${(widget.items.length / 2).ceil()} items to submit',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.amber, fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 12),
        ...List.generate(widget.items.length, (i) {
          return GestureDetector(
            onTap: () {
              setState(() => _checked[i] = !_checked[i]);
              widget.onChanged(List.from(_checked));
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _checked[i]
                    ? AppColors.darkGreen.withOpacity(0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _checked[i]
                      ? AppColors.darkGreen.withOpacity(0.4)
                      : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _checked[i]
                          ? AppColors.darkGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _checked[i]
                            ? AppColors.darkGreen
                            : AppColors.textHint,
                        width: 2,
                      ),
                    ),
                    child: _checked[i]
                        ? const Icon(Icons.check,
                        color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.items[i],
                      style: TextStyle(
                        fontSize: 13,
                        color: _checked[i]
                            ? AppColors.textDark
                            : AppColors.textMid,
                        decoration: _checked[i]
                            ? TextDecoration.lineThrough
                            : null,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}