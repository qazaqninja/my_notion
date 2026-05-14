import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';

/// Source-mode editor — monospace `TextField` with the markdown body.
/// Syntax-highlighting comes in a follow-up (the design uses subtle tinting
/// for headings, frontmatter keys, and `[[ULID]]` blocks); v1 just gives a
/// clean mono field with body-color text.
class SourceView extends StatefulWidget {
  const SourceView({super.key, required this.initialText});
  final String initialText;

  @override
  State<SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<SourceView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(SourceView old) {
    super.didUpdateWidget(old);
    // Re-sync if the page identity changed but the controller is stale.
    if (widget.initialText != old.initialText && _controller.text != widget.initialText) {
      _controller.value = TextEditingValue(text: widget.initialText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    context.read<EditorBloc>().add(EditBody(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: TextField(
        controller: _controller,
        maxLines: null,
        minLines: 8,
        decoration: const InputDecoration.collapsed(hintText: ''),
        style: mono(fontSize: 13.5, color: tokens.text).copyWith(height: 1.65),
      ),
    );
  }
}
