import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';
import 'quill_menu.dart';

class QuillSelectOption<T> {
  const QuillSelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.hint,
  });
  final T value;
  final String label;
  final String? icon;
  final String? hint;
}

/// Anchored dropdown — replaces `DropdownButton<T>`. Trigger is a small
/// inset row showing the current label; tap opens a [showQuillMenu] anchored
/// below the trigger with one item per option.
class QuillSelect<T> extends StatefulWidget {
  const QuillSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 160,
    this.mono = false,
    this.placeholder,
    this.dense = false,
  });

  final T value;
  final List<QuillSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final double width;
  final bool mono;
  final String? placeholder;
  final bool dense;

  @override
  State<QuillSelect<T>> createState() => _QuillSelectState<T>();
}

class _QuillSelectState<T> extends State<QuillSelect<T>> {
  bool _hover = false;

  String _labelFor(T v) {
    for (final o in widget.options) {
      if (o.value == v) return o.label;
    }
    return widget.placeholder ?? '';
  }

  Future<void> _open() async {
    final position = quillMenuAnchor(context);
    final picked = await showQuillMenu<T>(
      context: context,
      position: position,
      width: widget.width,
      items: [
        for (final o in widget.options)
          QuillMenuItem<T>(
            icon: o.icon,
            label: o.label,
            hint: o.hint,
            value: o.value,
          ),
      ],
    );
    if (picked != null && picked != widget.value) {
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final label = _labelFor(widget.value);
    final pad = widget.dense
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 7);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Container(
          width: widget.width,
          padding: pad,
          decoration: BoxDecoration(
            color: _hover ? tokens.hover : tokens.inputBg,
            border: Border.all(color: tokens.divider2, width: 0.5),
            borderRadius:
                BorderRadius.all(Radius.circular(widget.dense ? 5 : 6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: widget.mono ? 'JetBrainsMono' : null,
                    fontSize: widget.dense ? 12.5 : 13,
                    color: tokens.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              QuillIcon('caret-down',
                  size: 11, strokeWidth: 1.7, color: tokens.text3),
            ],
          ),
        ),
      ),
    );
  }
}
