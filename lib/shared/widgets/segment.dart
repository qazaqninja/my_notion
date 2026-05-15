import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';

class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });
  final T value;
  final String label;
  final String? icon;

  /// Optional hover hint. Useful when `label` is a one-letter abbreviation
  /// (S/M/L on a card-size switcher) — the tooltip can carry the full word.
  final String? tooltip;
}

/// Segmented control — view switcher, mode toggle, etc. Matches `Segment`
/// from `primitives.jsx:125-153`.
class Segment<T> extends StatelessWidget {
  const Segment({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.size = SegmentSize.md,
  });

  final T value;
  final List<SegmentOption<T>> options;
  final ValueChanged<T> onChanged;
  final SegmentSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final pad = size == SegmentSize.sm
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 11, vertical: 5);
    final fontSize = size == SegmentSize.sm ? 12.0 : 12.5;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: tokens.divider2, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) {
          final selected = o.value == value;
          Widget tile = MouseRegion(
            cursor: selected
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onChanged(o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: pad,
                decoration: BoxDecoration(
                  color: selected
                      ? (tokens.isDark ? const Color(0xFF33312D) : const Color(0xFFFBFAF6))
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  border: selected
                      ? Border.all(color: tokens.divider2, width: 0.5)
                      : null,
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (o.icon != null) ...[
                      QuillIcon(o.icon!, size: 13, strokeWidth: 1.7,
                          color: selected ? tokens.text : tokens.text2),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      o.label,
                      style: TextStyle(
                        color: selected ? tokens.text : tokens.text2,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          if (o.tooltip != null) {
            tile = Tooltip(
              message: o.tooltip!,
              waitDuration: const Duration(milliseconds: 500),
              child: tile,
            );
          }
          return tile;
        }).toList(),
      ),
    );
  }
}

enum SegmentSize { sm, md }
