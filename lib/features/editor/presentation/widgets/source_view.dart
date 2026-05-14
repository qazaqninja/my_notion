import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../../relations/presentation/cubit/relation_picker_cubit.dart';
import '../../../relations/presentation/widgets/relation_picker_overlay.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../domain/attachment_writer.dart';
import '../../domain/slash_entries.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../cubit/slash_menu_cubit.dart';
import 'slash_menu_overlay.dart';

/// Source-mode editor — monospace `TextField` with the markdown body.
/// Watches for `[[` typed before the cursor and pops the relation picker
/// to splice `[[ULID]]` once a target is chosen.
class SourceView extends StatefulWidget {
  const SourceView({super.key, required this.initialText});
  final String initialText;

  @override
  State<SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<SourceView> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late final RelationPickerCubit _picker;
  late final SlashMenuCubit _slash;
  final GlobalKey _fieldKey = GlobalKey();
  int? _triggerStart;
  int? _slashTriggerStart;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
    _picker = RelationPickerCubit(SearchPages(context.read<QuillDatabase>()));
    _slash = SlashMenuCubit();
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(SourceView old) {
    super.didUpdateWidget(old);
    if (widget.initialText != old.initialText && _controller.text != widget.initialText) {
      _controller.value = TextEditingValue(text: widget.initialText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    _picker.dismiss();
    _slash.close();
    super.dispose();
  }

  void _onChanged() {
    context.read<EditorBloc>().add(EditBody(_controller.text));

    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || selection.start != selection.end) {
      if (_picker.state.open) _picker.dismiss();
      if (_slash.state.open) {
        _slash.dismiss();
        _slashTriggerStart = null;
      }
      return;
    }
    final caret = selection.start;

    // --- Slash menu trigger / query update ----------------------------------
    if (_slashTriggerStart == null) {
      // A fresh `/` immediately after start-of-line or whitespace fires it.
      if (caret >= 1 && text[caret - 1] == '/') {
        final atStart = caret == 1;
        final prevChar = caret >= 2 ? text[caret - 2] : '';
        final boundary = prevChar.isEmpty ||
            prevChar == '\n' ||
            prevChar == ' ' ||
            prevChar == '\t';
        if (atStart || boundary) {
          _slashTriggerStart = caret;
          final rect = _caretRect() ?? Rect.zero;
          _slash.openAt(anchor: rect, triggerOffset: caret - 1);
        }
      }
    } else {
      final start = _slashTriggerStart!;
      if (caret < start || start > text.length) {
        _slash.dismiss();
        _slashTriggerStart = null;
      } else {
        final between = text.substring(start, caret);
        if (between.contains('\n') || between.contains(' ')) {
          _slash.dismiss();
          _slashTriggerStart = null;
        } else {
          _slash.setQuery(between);
        }
      }
    }

    // --- Relation picker trigger / query update -----------------------------
    if (_triggerStart == null) {
      // Detect a freshly-typed `[[` ending at the caret.
      if (caret >= 2 && text.substring(caret - 2, caret) == '[[') {
        _triggerStart = caret;
        final rect = _caretRect() ?? Rect.zero;
        _picker.openAt(anchor: rect, sourceOffset: caret - 2);
      }
      return;
    }

    // Picker is open — update query or close if context invalidated.
    final start = _triggerStart!;
    if (caret < start || start > text.length) {
      _picker.dismiss();
      _triggerStart = null;
      return;
    }
    // If anything between the `[[` and caret looks like a hard boundary
    // (newline, `]`), close.
    final between = text.substring(start, caret);
    if (between.contains('\n') || between.contains(']')) {
      _picker.dismiss();
      _triggerStart = null;
      return;
    }
    _picker.setQuery(between);
  }

  Rect? _caretRect() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final origin = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(origin.dx, origin.dy + box.size.height - 20, 320, 0);
  }

  /// When the relation picker OR slash menu is open, intercept
  /// ↑ / ↓ / ↵ / esc to drive selection without losing keyboard focus.
  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // Slash menu takes precedence (it's text-driven, so it opens last).
    if (_slash.state.open) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _slash.move(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _slash.move(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        final selected = _slash.state.selected;
        if (selected != null) {
          _onSlashPick(selected);
          return KeyEventResult.handled;
        }
      }
      if (key == LogicalKeyboardKey.escape) {
        _slashTriggerStart = null;
        _slash.dismiss();
        return KeyEventResult.handled;
      }
    }

    if (!_picker.state.open) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      _picker.move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _picker.move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final selected = _picker.state.selectedResult;
      if (selected != null) {
        _onPick(selected);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      _triggerStart = null;
      _picker.dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _onSlashPick(SlashEntry entry) async {
    final triggerOffset = _slashTriggerStart;
    if (triggerOffset == null) return;
    final stripStart = triggerOffset - 1;

    switch (entry.action) {
      case SlashAction.insertSnippet:
        final text = _controller.text;
        final caret = _controller.selection.start;
        final newText = text.replaceRange(stripStart, caret, entry.snippet);
        final newCaret = entry.caretAfterInsert(stripStart);
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCaret),
        );
      case SlashAction.pickImage:
        // Strip the `/...` trigger first so the picker dialog opens with the
        // editor in a clean state. The async picker is awaited below.
        final text = _controller.text;
        final caret = _controller.selection.start;
        final cleared = text.replaceRange(stripStart, caret, '');
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart),
        );
        _slashTriggerStart = null;
        _slash.dismiss();
        await _pickAndInsertImage(stripStart);
        return;
    }

    _slashTriggerStart = null;
    _slash.dismiss();
  }

  Future<void> _pickAndInsertImage(int insertAt) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;
    try {
      final relative = await const AttachmentWriter().copy(
        source: File(picked.path!),
        vaultRoot: Directory(vault.rootPath),
      );
      final snippet = '![image]($relative)';
      final text = _controller.text;
      final at = insertAt.clamp(0, text.length);
      final newText = text.replaceRange(at, at, snippet);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: at + snippet.length),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Image copy failed: $e')));
    }
  }

  void _onPick(PageSearchResult result) {
    final start = _triggerStart;
    if (start == null) return;
    final text = _controller.text;
    final caret = _controller.selection.start;
    final insertion = '[[${result.ulid}]]';
    final newText = text.replaceRange(start - 2, caret, insertion);
    final newCaret = start - 2 + insertion.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
    );
    _triggerStart = null;
    _picker.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return MultiBlocProvider(
      providers: [
        BlocProvider<RelationPickerCubit>.value(value: _picker),
        BlocProvider<SlashMenuCubit>.value(value: _slash),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            key: _fieldKey,
            margin: const EdgeInsets.symmetric(vertical: 24),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Focus(
              onKeyEvent: _onKeyEvent,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                maxLines: null,
                minLines: 8,
                decoration: const InputDecoration.collapsed(hintText: ''),
                style: mono(fontSize: 13.5, color: tokens.text).copyWith(height: 1.65),
              ),
            ),
          ),
          RelationPickerOverlay(
            onPick: _onPick,
            onDismiss: () {
              _triggerStart = null;
              _picker.dismiss();
            },
          ),
          SlashMenuOverlay(
            onPick: _onSlashPick,
            onDismiss: () {
              _slashTriggerStart = null;
              _slash.dismiss();
            },
          ),
        ],
      ),
    );
  }
}
