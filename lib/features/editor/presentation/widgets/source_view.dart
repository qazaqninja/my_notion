import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/ui/anchor_rect.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../../relations/presentation/cubit/relation_picker_cubit.dart';
import '../../../relations/presentation/widgets/relation_picker_overlay.dart';
import '../../../vault/data/daily_note.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_event.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../domain/attachment_writer.dart';
import '../../domain/emoji_shortcodes.dart';
import '../../domain/insert_link.dart';
import '../../domain/slash_entries.dart';
import '../../domain/source_line_ops.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_state.dart';
import '../bloc/editor_event.dart';
import '../cubit/slash_menu_cubit.dart';
import 'slash_menu_overlay.dart';

/// Source-mode editor — monospace `TextField` with the markdown body.
/// Watches for `[[` typed before the cursor and pops the relation picker
/// to splice `[[ULID]]` once a target is chosen.
class SourceView extends StatefulWidget {
  const SourceView({
    super.key,
    required this.initialText,
    this.locked = false,
  });
  final String initialText;

  /// When true, the TextField is read-only and the controller listener
  /// skips dispatching EditBody (which would otherwise be silently
  /// swallowed by EditorBloc, see editor_bloc.dart:112). Mirrors the
  /// kebab/title/properties-panel locked guards (M679–M681).
  final bool locked;

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

  /// Number of characters the trigger sequence occupies. `[[` → 2, `@` → 1.
  /// Used by [_onPick] to know how much prefix to strip when splicing.
  int _triggerLen = 2;
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
    // When the page is locked, EditorBloc.EditBody silently returns and
    // the local controller would drift ahead of the saved page. The
    // TextField is also read-only at the widget level — this guard is
    // belt-and-suspenders for any programmatic mutations.
    if (widget.locked) return;
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
          _slash.openAt(anchor: _toAnchorRect(rect), triggerOffset: caret - 1);
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
        _triggerLen = 2;
        final rect = _caretRect() ?? Rect.zero;
        _picker.openAt(anchor: _toAnchorRect(rect), sourceOffset: caret - 2);
        return;
      }
      // Detect a freshly-typed `@` at start-of-line or after whitespace.
      // Requires the previous boundary to be empty / newline / whitespace
      // so we don't fire on emails like `foo@bar.com`.
      if (caret >= 1 && text[caret - 1] == '@') {
        final prev = caret >= 2 ? text[caret - 2] : '';
        final boundary = prev.isEmpty ||
            prev == '\n' ||
            prev == ' ' ||
            prev == '\t' ||
            prev == '(' ||
            prev == '[';
        if (boundary) {
          _triggerStart = caret;
          _triggerLen = 1;
          final rect = _caretRect() ?? Rect.zero;
          _picker.openAt(anchor: _toAnchorRect(rect), sourceOffset: caret - 1);
        }
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
    final between = text.substring(start, caret);
    // Trigger-specific close boundaries:
    //   `[[`: close on newline or `]` (since the user likely typed `]]`)
    //   `@` : close on newline or whitespace (Notion-style mention scope)
    final closes = _triggerLen == 2
        ? (between.contains('\n') || between.contains(']'))
        : (between.contains('\n') || between.contains(' ') || between.contains('\t'));
    if (closes) {
      _picker.dismiss();
      _triggerStart = null;
      return;
    }
    _picker.setQuery(between);
  }

  Rect? _caretRect() {
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null) return null;

    // Walk the field's descendants to find the TextField's RenderEditable.
    RenderEditable? editable;
    void visit(RenderObject node) {
      if (editable != null) return;
      if (node is RenderEditable) {
        editable = node;
        return;
      }
      node.visitChildren(visit);
    }
    fieldBox.visitChildren(visit);

    if (editable == null) {
      // Fallback: anchor near the top of the field rather than the bottom
      // so a misaligned popover at least stays in viewport.
      return Rect.fromLTWH(40, 24, 320, 0);
    }

    final caret = _controller.selection.extent;
    final localCaret = editable!.getLocalRectForCaret(caret);
    final caretInField =
        editable!.localToGlobal(localCaret.bottomLeft, ancestor: fieldBox);

    // Clamp x so the 320-wide panel doesn't run off the right side.
    final maxX = (fieldBox.size.width - 320).clamp(0.0, double.infinity);
    final x = caretInField.dx.clamp(0.0, maxX);
    return Rect.fromLTWH(x, caretInField.dy, 320, 0);
  }

  /// Convert a Flutter [Rect] to the plain-Dart [AnchorRect] used by the
  /// cubit states. Keeps the bloc/cubit layer Flutter-free per CA-01.
  static AnchorRect _toAnchorRect(Rect r) =>
      AnchorRect(left: r.left, top: r.top, right: r.right, bottom: r.bottom);

  /// Tab / Shift-Tab on the current selection. Indents or outdents
  /// every line touched by the selection (or the line under the caret
  /// when there's no range). Uses two spaces — the same width the
  /// renderer treats as a nested-list indent.
  void _indentSelection(bool outdent) {
    final v = _controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final text = v.text;
    final selStart = sel.start.clamp(0, text.length);
    final selEnd = sel.end.clamp(0, text.length);
    final lineStart = selStart == 0
        ? 0
        : (text.lastIndexOf('\n', selStart - 1) + 1);
    var lineEndExclusive = text.indexOf('\n', selEnd);
    if (lineEndExclusive < 0) lineEndExclusive = text.length;
    final block = text.substring(lineStart, lineEndExclusive);
    const indent = '  ';
    final newBlock = block
        .split('\n')
        .map((line) {
          if (outdent) {
            if (line.startsWith(indent)) return line.substring(indent.length);
            if (line.startsWith(' ')) return line.substring(1);
            return line;
          }
          return '$indent$line';
        })
        .join('\n');
    final delta = newBlock.length - block.length;
    final newText = text.replaceRange(lineStart, lineEndExclusive, newBlock);
    _controller.value = v.copyWith(
      text: newText,
      selection: TextSelection(
        baseOffset: selStart + (outdent ? -2 : 2).clamp(-selStart + lineStart, delta),
        extentOffset: selEnd + delta,
      ),
    );
  }

  /// Duplicate the line under the caret and place the caret at the
  /// same column on the copy. Cmd+D / Ctrl+D.
  void _duplicateLine() {
    _applyLineOp(duplicateLineAt);
  }

  /// Move the line under the caret up by one. Alt+↑.
  void _moveLineUp() {
    _applyLineOp(moveLineUp);
  }

  /// Move the line under the caret down by one. Alt+↓.
  void _moveLineDown() {
    _applyLineOp(moveLineDown);
  }

  /// Toggle an HTML comment around the line under the caret. Cmd+/.
  void _toggleComment() {
    _applyLineOp(toggleCommentLine);
  }

  /// Delete the line under the caret. Cmd+Shift+K / Ctrl+Shift+K.
  void _deleteLine() {
    _applyLineOp(deleteLineAt);
  }

  /// Join the current line with the next. Cmd+J / Ctrl+J.
  void _joinLines() {
    _applyLineOp(joinLineWithNext);
  }

  /// Convert the current line to a heading of [level] (1, 2, or 3). Cmd+⇧+N.
  void _setHeadingLevel(int level) {
    final prefix = '${'#' * level} ';
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, prefix));
  }

  /// Strip any leading block marker on the current line (heading, list,
  /// quote, …) back to plain paragraph. Cmd+⇧+0.
  void _stripLinePrefix() {
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, ''));
  }

  /// Convert the current line to a `> ` blockquote. Cmd+⇧+. (mnemonic:
  /// the period sits on the same key as `>` on US layouts).
  void _convertToQuote() {
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, '> '));
  }

  /// Convert the current line to `- ` bullet. Cmd+⇧+8 (mnemonic: `*`).
  void _convertToBullet() {
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, '- '));
  }

  /// Convert the current line to `1. ` numbered. Cmd+⇧+7. Existing
  /// items below aren't re-numbered — the user typed `1.` intent.
  void _convertToNumbered() {
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, '1. '));
  }

  /// Convert the current line to `- [ ] ` to-do. Cmd+⇧+T.
  void _convertToTodo() {
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, '- [ ] '));
  }

  /// Convert the current line to a `> [!NOTE] ` callout. Cmd+⇧+M
  /// (mnemonic: 'M' for admonition / 'memo').
  void _convertToCallout() {
    _applyLineOp((text, caret) => applyLinePrefix(text, caret, '> [!NOTE] '));
  }

  /// Toggle `- [ ] ` ↔ `- [x] ` on the current line. Cmd+Enter.
  /// No-op on non-todo lines (callers fall through to default Enter).
  void _toggleTodoState() {
    final v = _controller.value;
    final caret = v.selection.isValid ? v.selection.baseOffset : v.text.length;
    final r = toggleTodoAt(v.text, caret);
    if (r == null) return;
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.caret),
    );
  }

  /// Insert a horizontal rule (`\n---\n`) at the caret. Cmd+⇧+-.
  void _insertHorizontalRule() {
    final v = _controller.value;
    final caret =
        v.selection.isValid ? v.selection.baseOffset : v.text.length;
    // Make sure the rule sits on its own line. Inspect the chars around
    // the caret so we don't double up newlines.
    final before = caret > 0 ? v.text[caret - 1] : '\n';
    final after = caret < v.text.length ? v.text[caret] : '\n';
    final prefix = before == '\n' ? '' : '\n';
    final suffix = after == '\n' ? '' : '\n';
    final insert = '$prefix---\n$suffix';
    final newText = v.text.replaceRange(caret, caret, insert);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret + insert.length),
    );
  }

  /// Open the "insert link" dialog. ⌘K. Three modes:
  /// 1. Caret inside an existing `[label](url)` → EDIT mode; URL field
  ///    pre-fills with the current URL.
  /// 2. Non-empty selection → WRAP mode; label = selection, URL from
  ///    clipboard when clipboard looks like a URL.
  /// 3. No selection / no surrounding link → INSERT mode; label = "link".
  ///
  /// Inert when the page is locked.
  Future<void> _openLinkDialog() async {
    final v = _controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final start = sel.start.clamp(0, v.text.length);
    final end = sel.end.clamp(start, v.text.length);
    final selected = v.text.substring(start, end);

    // EDIT mode kicks in only when the user has a collapsed caret
    // inside an existing link. A non-empty selection always means WRAP.
    final existing = selected.isEmpty
        ? findMarkdownLinkAt(v.text, start)
        : null;

    final String urlSeed;
    if (existing != null) {
      urlSeed = existing.url;
    } else {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final clipText = clip?.text?.trim() ?? '';
      urlSeed = looksLikeUrl(clipText) ? clipText : '';
    }

    if (!mounted) return;
    final url = await showQuillPrompt(
      context,
      title: existing != null ? 'Edit link' : 'Insert link',
      icon: 'link',
      label: 'URL',
      hint: existing != null
          ? 'Editing the link around the caret.'
          : selected.isEmpty
              ? 'The URL gets a "link" label by default.'
              : 'Wraps the current selection.',
      placeholder: 'https://example.com',
      initial: urlSeed,
      mono: true,
      confirmLabel: existing != null ? 'Save' : 'Insert',
    );
    if (url == null || url.trim().isEmpty) return;

    final String label;
    final int replaceStart;
    final int replaceEnd;
    if (existing != null) {
      label = existing.label;
      replaceStart = existing.start;
      replaceEnd = existing.end;
    } else {
      label = selected.isEmpty ? 'link' : selected;
      replaceStart = start;
      replaceEnd = end;
    }
    final r = insertMarkdownLink(
      text: v.text,
      start: replaceStart,
      end: replaceEnd,
      label: label,
      url: url.trim(),
    );
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.caret),
    );
  }

  /// Smart paste: when the clipboard contains a URL and the user has a
  /// non-empty selection, wrap the selection as `[selected](url)`. In
  /// every other case, paste the clipboard text in place — same shape
  /// as default ⌘V.
  ///
  /// Intercepting ⌘V completely replaces the platform paste path, so
  /// this handler must cover every case (selection / no-selection,
  /// URL / non-URL) — it does.
  Future<void> _smartPaste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text ?? '';
    if (text.isEmpty) return;
    if (!mounted) return;

    final v = _controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final start = sel.start.clamp(0, v.text.length);
    final end = sel.end.clamp(start, v.text.length);
    final selected = v.text.substring(start, end);

    if (selected.isNotEmpty && looksLikeUrl(text)) {
      // Reuse insertMarkdownLink so wrap-on-paste and ⌘K go through
      // the same splice path. Tested by insert_link_test.dart.
      final r = insertMarkdownLink(
        text: v.text,
        start: start,
        end: end,
        label: selected,
        url: text.trim(),
      );
      _controller.value = TextEditingValue(
        text: r.text,
        selection: TextSelection.collapsed(offset: r.caret),
      );
      return;
    }
    final newText = v.text.replaceRange(start, end, text);
    final caretAfter = start + text.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caretAfter),
    );
  }

  void _applyLinesTransform(
    SortLinesResult Function(String text, int start, int end) op,
  ) {
    final v = _controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final r = op(v.text, sel.start, sel.end);
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection(
        baseOffset: r.selectionStart,
        extentOffset: r.selectionEnd,
      ),
    );
  }

  /// Sort the lines touched by the current selection, case-insensitive
  /// ascending. ⌘⇧S in source mode.
  void _sortSelectedLines() => _applyLinesTransform(sortLinesIn);

  /// Remove duplicate lines from the selected block, keeping the first
  /// occurrence of each. ⌘⌥D in source mode.
  void _dedupeSelectedLines() => _applyLinesTransform(dedupeLinesIn);

  /// Reverse the order of the lines in the selected block. ⌘⌥R isn't
  /// available (shell uses it for reveal), so this is bound from the
  /// slash menu with a "Reverse lines" entry.
  void _reverseSelectedLines() => _applyLinesTransform(reverseLinesIn);

  /// Select the current line (between the surrounding newlines). Cmd+L.
  void _selectCurrentLine() {
    final v = _controller.value;
    final caret = v.selection.isValid ? v.selection.baseOffset : v.text.length;
    final r = lineRangeAt(v.text, caret);
    _controller.value = v.copyWith(
      selection: TextSelection(baseOffset: r.start, extentOffset: r.end),
    );
  }

  void _applyLineOp(LineOpResult Function(String text, int caret) op) {
    final v = _controller.value;
    final caret = v.selection.isValid ? v.selection.baseOffset : v.text.length;
    final r = op(v.text, caret);
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.caret),
    );
  }

  /// Wrap the current selection (or insert two markers and place the
  /// caret between them) with [pre]/[post]. Cmd+B → **bold**, Cmd+I →
  /// *italic*.
  void _wrapSelection(String pre, String post) {
    final v = _controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final start = sel.start.clamp(0, v.text.length);
    final end = sel.end.clamp(0, v.text.length);
    final selected = v.text.substring(start, end);
    final replaced = '$pre$selected$post';
    final newText = v.text.replaceRange(start, end, replaced);
    final caretAfter = selected.isEmpty
        ? start + pre.length // insert caret between markers
        : start + replaced.length;
    _controller.value = v.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: caretAfter),
    );
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
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.tab) {
        final selected = _slash.state.selected;
        if (selected != null) {
          _onSlashPick(selected);
          return KeyEventResult.handled;
        }
        // No match — dismiss instead of letting Enter / Tab fall
        // through to a newline or indent.
        _slashTriggerStart = null;
        _slash.dismiss();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _slashTriggerStart = null;
        _slash.dismiss();
        return KeyEventResult.handled;
      }
    }

    // Backspace at end of an empty list marker strips the marker
    // (keeping the indent). The standard "press Backspace to exit a
    // bullet" UX.
    if (!widget.locked &&
        !_slash.state.open &&
        !_picker.state.open &&
        key == LogicalKeyboardKey.backspace &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isControlPressed) {
      final v = _controller.value;
      if (v.selection.isValid &&
          v.selection.baseOffset == v.selection.extentOffset) {
        final r = backspaceListMarker(v.text, v.selection.baseOffset);
        if (r != null) {
          _controller.value = TextEditingValue(
            text: r.text,
            selection: TextSelection.collapsed(offset: r.caret),
          );
          return KeyEventResult.handled;
        }
      }
    }

    // Smart-Enter continuation for list lines (only when no picker is
    // intercepting). Shift+Enter keeps the platform's plain-newline
    // behaviour for users who want to break out of the list.
    if (!widget.locked &&
        !_slash.state.open &&
        !_picker.state.open &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final v = _controller.value;
      final caret = v.selection.isValid
          ? v.selection.baseOffset
          : v.text.length;
      // Only fire when there's no active selection — replacing a
      // selection with a list-continuation is more surprising than
      // useful.
      if (v.selection.baseOffset == v.selection.extentOffset) {
        final r = continueListAtNewline(v.text, caret);
        if (r != null) {
          _controller.value = TextEditingValue(
            text: r.text,
            selection: TextSelection.collapsed(offset: r.caret),
          );
          return KeyEventResult.handled;
        }
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
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      // Tab as autocomplete on an open picker — mirrors IDE / Slack
      // pattern. Without this Tab would fall through to _indentSelection,
      // which mangles the [[ trigger.
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
    final text = _controller.text;
    final caret = _controller.selection.start;

    // CRITICAL: clear trigger state BEFORE mutating the controller. The
    // controller's listener fires synchronously when we assign `.value`,
    // re-entering `_onChanged`. If `_slashTriggerStart` is still set, the
    // listener tries to re-evaluate the slash menu against the spliced
    // text — for snippets without space/newline (e.g. `[[`) the slash
    // stays open AND the relation picker also opens, intercepting all
    // keyboard input until the user blindly clicks somewhere safe.
    // Also clear the relation-picker trigger so the same snippet (`[[`)
    // doesn't get caught by it.
    _slashTriggerStart = null;
    _triggerStart = null;
    _slash.dismiss();

    switch (entry.action) {
      case SlashAction.insertSnippet:
        // Convert-in-place: when the entry declares a linePrefix, strip
        // any existing markdown prefix on the current line and prepend
        // the new one. Keeps the line's content; just changes its block
        // type. Matches Notion's slash-on-existing-block behaviour.
        if (entry.linePrefix != null) {
          final lineStart = stripStart == 0
              ? 0
              : (text.lastIndexOf('\n', stripStart - 1) + 1);
          final beforeSlash = text.substring(lineStart, stripStart);
          final stripped = beforeSlash.replaceFirst(
            RegExp(r'^(#{1,3} |- \[[ xX]\] |- |\* |> |\d+\. )'),
            '',
          );
          final insertion = '${entry.linePrefix}$stripped';
          final newText = text.replaceRange(lineStart, caret, insertion);
          final newCaret = lineStart + entry.linePrefix!.length;
          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCaret),
          );
        } else {
          final newText = text.replaceRange(stripStart, caret, entry.snippet);
          final newCaret = entry.caretAfterInsert(stripStart);
          _controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCaret),
          );
        }
      case SlashAction.pickImage:
        // Strip the `/...` trigger first so the picker dialog opens with the
        // editor in a clean state. The async picker is awaited below.
        final cleared = text.replaceRange(stripStart, caret, '');
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart),
        );
        await _pickAndInsertImage(stripStart);
      case SlashAction.pickFile:
        final cleared = text.replaceRange(stripStart, caret, '');
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart),
        );
        await _pickAndInsertFile(stripStart);
      case SlashAction.insertDailyNoteLink:
        final cleared = text.replaceRange(stripStart, caret, '');
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart),
        );
        await _insertDailyNoteLink(stripStart);
      case SlashAction.insertToday:
        final today = DateTime.now();
        final yyyy = today.year.toString().padLeft(4, '0');
        final mm = today.month.toString().padLeft(2, '0');
        final dd = today.day.toString().padLeft(2, '0');
        final snippet = '@$yyyy-$mm-$dd';
        final newText = text.replaceRange(stripStart, caret, snippet);
        _controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.collapsed(offset: stripStart + snippet.length),
        );
      case SlashAction.insertTimestamp:
        final now = DateTime.now();
        final yyyy = now.year.toString().padLeft(4, '0');
        final mm = now.month.toString().padLeft(2, '0');
        final dd = now.day.toString().padLeft(2, '0');
        final hh = now.hour.toString().padLeft(2, '0');
        final mi = now.minute.toString().padLeft(2, '0');
        final snippet = '$yyyy-$mm-$dd $hh:$mi';
        final newText = text.replaceRange(stripStart, caret, snippet);
        _controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.collapsed(offset: stripStart + snippet.length),
        );
      case SlashAction.pickEmoji:
        // Strip the `/...` trigger first so the picker opens with a
        // clean caret position.
        final cleared = text.replaceRange(stripStart, caret, '');
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart),
        );
        await _pickAndInsertEmoji(stripStart);
      case SlashAction.insertRandomPageLink:
        final cleared = text.replaceRange(stripStart, caret, '');
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart),
        );
        await _insertRandomPageLink(stripStart);
      case SlashAction.insertCurrentUser:
        final vault = context.read<VaultBloc>().state;
        final name = vault is VaultLoaded
            ? (vault.workspace.currentUserName ?? '')
            : '';
        if (name.isEmpty) {
          final cleared = text.replaceRange(stripStart, caret, '');
          _controller.value = TextEditingValue(
            text: cleared,
            selection: TextSelection.collapsed(offset: stripStart),
          );
          context.toastInfo('No current user — add one in Settings → Users');
          return;
        }
        final snippet = '@$name';
        final newText = text.replaceRange(stripStart, caret, snippet);
        _controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.collapsed(offset: stripStart + snippet.length),
        );
      case SlashAction.reverseSelectedLines:
        // Strip the `/reverse` trigger before transforming so the
        // helper sees the user's actual content. After that, run
        // reverseLinesIn on whatever the caret is now sitting in.
        final cleared = text.replaceRange(stripStart, caret, '');
        final cursor = stripStart;
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: cursor),
        );
        _reverseSelectedLines();
      case SlashAction.expandEmojiShortcodes:
        // Strip the `/expand` trigger first, then scan the whole body
        // for `:shortcode:` patterns and replace each with its emoji.
        final cleared = text.replaceRange(stripStart, caret, '');
        final expanded = replaceEmojiShortcodes(cleared);
        // Caret lands where the trigger used to be — the splice can
        // shift offsets to the right of stripStart, but the user
        // typed the slash command at stripStart so that's the
        // expected landing point.
        _controller.value = TextEditingValue(
          text: expanded,
          selection: TextSelection.collapsed(
            offset: stripStart.clamp(0, expanded.length),
          ),
        );
      case SlashAction.trimTrailingWhitespace:
        // Strip the `/trim` trigger first, then run the whitespace
        // cleanup on the whole body.
        final cleared = text.replaceRange(stripStart, caret, '');
        final trimmed = trimTrailingWhitespaceIn(cleared, 0, cleared.length);
        _controller.value = TextEditingValue(
          text: trimmed.text,
          selection: TextSelection.collapsed(
            offset: stripStart.clamp(0, trimmed.text.length),
          ),
        );
      case SlashAction.uppercaseSelectedLines:
        _applyLinesTransformAfterSlash(stripStart, caret, uppercaseLinesIn);
      case SlashAction.lowercaseSelectedLines:
        _applyLinesTransformAfterSlash(stripStart, caret, lowercaseLinesIn);
      case SlashAction.titleCaseSelectedLines:
        _applyLinesTransformAfterSlash(stripStart, caret, titleCaseLinesIn);
      case SlashAction.insertUlid:
        // Strip the trigger first, then splice a freshly-generated ULID.
        final ulid = const UlidGenerator().generate();
        final cleared = text.replaceRange(stripStart, caret, ulid);
        _controller.value = TextEditingValue(
          text: cleared,
          selection: TextSelection.collapsed(offset: stripStart + ulid.length),
        );
      case SlashAction.insertYesterday:
        _insertRelativeDate(stripStart, caret, const Duration(days: -1));
      case SlashAction.insertTomorrow:
        _insertRelativeDate(stripStart, caret, const Duration(days: 1));
      case SlashAction.sortLinesDescending:
        _applyLinesTransformAfterSlash(stripStart, caret, sortLinesDescIn);
    }
  }

  /// Insert `@YYYY-MM-DD` for `DateTime.now() + offset` at the caret,
  /// replacing the slash trigger.
  void _insertRelativeDate(int stripStart, int caret, Duration offset) {
    final v = _controller.value;
    final target = DateTime.now().add(offset);
    final yyyy = target.year.toString().padLeft(4, '0');
    final mm = target.month.toString().padLeft(2, '0');
    final dd = target.day.toString().padLeft(2, '0');
    final snippet = '@$yyyy-$mm-$dd';
    final newText = v.text.replaceRange(stripStart, caret, snippet);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: stripStart + snippet.length),
    );
  }

  /// Strip the slash trigger then apply [op] to the line under the
  /// caret. Used by the line-transform slash actions.
  void _applyLinesTransformAfterSlash(
    int stripStart,
    int caret,
    SortLinesResult Function(String, int, int) op,
  ) {
    final v = _controller.value;
    final cleared = v.text.replaceRange(stripStart, caret, '');
    final r = op(cleared, stripStart, stripStart);
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(
        offset: stripStart.clamp(0, r.text.length),
      ),
    );
  }

  Future<void> _insertRandomPageLink(int insertAt) async {
    final db = context.read<QuillDatabase>();
    // Snapshot the self-ULID synchronously so we don't reach into
    // `context` after the await.
    final loaded = context.read<EditorBloc>().state;
    final selfUlid = loaded is EditorLoaded ? loaded.page.ulid : '';
    final rows = await db.select(db.pages).get();
    if (!mounted) return;
    if (rows.isEmpty) {
      context.toastInfo('No pages to link to yet');
      return;
    }
    final pool = rows.where((r) => r.ulid != selfUlid).toList();
    if (pool.isEmpty) {
      context.toastInfo('This is the only page in the vault');
      return;
    }
    final pick = pool[DateTime.now().microsecondsSinceEpoch % pool.length];
    final t = _controller.text;
    final at = insertAt.clamp(0, t.length);
    final snippet = '[[${pick.ulid}]]';
    final newText = t.replaceRange(at, at, snippet);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: at + snippet.length),
    );
  }

  Future<void> _pickAndInsertEmoji(int insertAt) async {
    final picked = await pickEmoji(context);
    if (picked == null || picked.isEmpty) return;
    final t = _controller.text;
    final at = insertAt.clamp(0, t.length);
    final newText = t.replaceRange(at, at, picked);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: at + picked.length),
    );
  }

  Future<void> _insertDailyNoteLink(int insertAt) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    // Capture the bloc before the async gap so we don't reach into
    // context after awaiting (linter complaint).
    final vaultBloc = context.read<VaultBloc>();
    try {
      final result = await DailyNote.openTodaysNote(
        Directory(vault.rootPath),
      );
      final snippet = '[[${result.ulid}]]';
      final text = _controller.text;
      final at = insertAt.clamp(0, text.length);
      final newText = text.replaceRange(at, at, snippet);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: at + snippet.length),
      );
      if (!result.alreadyExisted) {
        vaultBloc.add(const ReindexVault());
      }
    } catch (e) {
      if (mounted) context.toastError('Daily note failed', sub: '$e');
    }
  }

  Future<void> _pickAndInsertFile(int insertAt) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) {
      if (mounted) {
        context.toastError('File has no readable path',
            sub: 'macOS sandbox or web-only file');
      }
      return;
    }
    try {
      final relative = await const AttachmentWriter().copy(
        source: File(picked.path!),
        vaultRoot: Directory(vault.rootPath),
      );
      // Label = original filename so the rendered card / chip carries
      // a meaningful name even after the ULID-rename inside attachments/.
      // Escape `[` and `]` so a filename like "report [v2].pdf" doesn't
      // truncate the alt at the first `]`. The URL part is always
      // attachments/<ULID>.<ext> which is ASCII-safe.
      final label = _escapeMarkdownAlt(picked.name);
      final snippet = '![$label]($relative)';
      final text = _controller.text;
      final at = insertAt.clamp(0, text.length);
      final newText = text.replaceRange(at, at, snippet);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: at + snippet.length),
      );
    } catch (e) {
      if (mounted) context.toastError('File copy failed', sub: '$e');
    }
  }

  /// Escape `[` `]` `\` in image / file alt text so the markdown
  /// `![alt](url)` form survives a filename like "report [v2].pdf".
  /// Order matters: backslashes first, then the brackets, otherwise
  /// the bracket escapes get double-escaped.
  static String _escapeMarkdownAlt(String name) => name
      .replaceAll(r'\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');

  Future<void> _pickAndInsertImage(int insertAt) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) {
      if (mounted) {
        context.toastError('Image has no readable path',
            sub: 'macOS sandbox or web-only file');
      }
      return;
    }
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
      if (mounted) context.toastError('Image copy failed', sub: '$e');
    }
  }

  void _onPick(PageSearchResult result) {
    final start = _triggerStart;
    if (start == null) return;
    final text = _controller.text;
    final caret = _controller.selection.start;
    final insertion = '[[${result.ulid}]]';
    final stripStart = start - _triggerLen;
    final newText = text.replaceRange(stripStart, caret, insertion);
    final newCaret = stripStart + insertion.length;
    // Reset before mutating the controller — see _onSlashPick for why.
    _triggerStart = null;
    _triggerLen = 2;
    _picker.dismiss();
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
    );
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
              child: CallbackShortcuts(
                // When the page is locked, suppress every mutating
                // shortcut. _onChanged already short-circuits the bloc
                // dispatch on locked (M682), but mutating shortcuts
                // bypass the TextField's readOnly by writing
                // _controller.value directly — that would leave the
                // local controller ahead of the bloc and lose edits
                // on close. Selecting the current line (⌘L) is
                // read-only so it's preserved.
                bindings: widget.locked
                    ? {
                        const SingleActivator(LogicalKeyboardKey.keyL,
                            meta: true): _selectCurrentLine,
                        const SingleActivator(LogicalKeyboardKey.keyL,
                            control: true): _selectCurrentLine,
                      }
                    : {
                  const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
                      () => _wrapSelection('**', '**'),
                  const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                      () => _wrapSelection('**', '**'),
                  const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
                      () => _wrapSelection('*', '*'),
                  const SingleActivator(LogicalKeyboardKey.keyI, control: true):
                      () => _wrapSelection('*', '*'),
                  const SingleActivator(LogicalKeyboardKey.keyX,
                      meta: true, shift: true): () => _wrapSelection('~~', '~~'),
                  const SingleActivator(LogicalKeyboardKey.keyX,
                      control: true, shift: true):
                      () => _wrapSelection('~~', '~~'),
                  const SingleActivator(LogicalKeyboardKey.keyC,
                      meta: true, shift: true): () => _wrapSelection('`', '`'),
                  const SingleActivator(LogicalKeyboardKey.keyC,
                      control: true, shift: true):
                      () => _wrapSelection('`', '`'),
                  const SingleActivator(LogicalKeyboardKey.keyH,
                      meta: true, shift: true):
                      () => _wrapSelection('==', '=='),
                  const SingleActivator(LogicalKeyboardKey.keyH,
                      control: true, shift: true):
                      () => _wrapSelection('==', '=='),
                  const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
                      _duplicateLine,
                  const SingleActivator(LogicalKeyboardKey.keyD,
                      control: true): _duplicateLine,
                  const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
                      _moveLineUp,
                  const SingleActivator(LogicalKeyboardKey.arrowDown,
                      alt: true): _moveLineDown,
                  const SingleActivator(LogicalKeyboardKey.slash, meta: true):
                      _toggleComment,
                  const SingleActivator(LogicalKeyboardKey.slash,
                      control: true): _toggleComment,
                  const SingleActivator(LogicalKeyboardKey.keyK,
                      meta: true, shift: true): _deleteLine,
                  const SingleActivator(LogicalKeyboardKey.keyK,
                      control: true, shift: true): _deleteLine,
                  const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
                      _selectCurrentLine,
                  const SingleActivator(LogicalKeyboardKey.keyL,
                      control: true): _selectCurrentLine,
                  const SingleActivator(LogicalKeyboardKey.keyJ, meta: true):
                      _joinLines,
                  const SingleActivator(LogicalKeyboardKey.keyJ,
                      control: true): _joinLines,
                  const SingleActivator(LogicalKeyboardKey.digit1,
                      meta: true, shift: true): () => _setHeadingLevel(1),
                  const SingleActivator(LogicalKeyboardKey.digit1,
                      control: true, shift: true): () => _setHeadingLevel(1),
                  const SingleActivator(LogicalKeyboardKey.digit2,
                      meta: true, shift: true): () => _setHeadingLevel(2),
                  const SingleActivator(LogicalKeyboardKey.digit2,
                      control: true, shift: true): () => _setHeadingLevel(2),
                  const SingleActivator(LogicalKeyboardKey.digit3,
                      meta: true, shift: true): () => _setHeadingLevel(3),
                  const SingleActivator(LogicalKeyboardKey.digit3,
                      control: true, shift: true): () => _setHeadingLevel(3),
                  const SingleActivator(LogicalKeyboardKey.digit0,
                      meta: true, shift: true): _stripLinePrefix,
                  const SingleActivator(LogicalKeyboardKey.digit0,
                      control: true, shift: true): _stripLinePrefix,
                  const SingleActivator(LogicalKeyboardKey.period,
                      meta: true, shift: true): _convertToQuote,
                  const SingleActivator(LogicalKeyboardKey.period,
                      control: true, shift: true): _convertToQuote,
                  const SingleActivator(LogicalKeyboardKey.digit8,
                      meta: true, shift: true): _convertToBullet,
                  const SingleActivator(LogicalKeyboardKey.digit8,
                      control: true, shift: true): _convertToBullet,
                  const SingleActivator(LogicalKeyboardKey.digit7,
                      meta: true, shift: true): _convertToNumbered,
                  const SingleActivator(LogicalKeyboardKey.digit7,
                      control: true, shift: true): _convertToNumbered,
                  const SingleActivator(LogicalKeyboardKey.keyT,
                      meta: true, shift: true): _convertToTodo,
                  const SingleActivator(LogicalKeyboardKey.keyT,
                      control: true, shift: true): _convertToTodo,
                  const SingleActivator(LogicalKeyboardKey.keyM,
                      meta: true, shift: true): _convertToCallout,
                  const SingleActivator(LogicalKeyboardKey.keyM,
                      control: true, shift: true): _convertToCallout,
                  const SingleActivator(LogicalKeyboardKey.enter,
                      meta: true): _toggleTodoState,
                  const SingleActivator(LogicalKeyboardKey.enter,
                      control: true): _toggleTodoState,
                  const SingleActivator(LogicalKeyboardKey.minus,
                      meta: true, shift: true): _insertHorizontalRule,
                  const SingleActivator(LogicalKeyboardKey.minus,
                      control: true, shift: true): _insertHorizontalRule,
                  const SingleActivator(LogicalKeyboardKey.tab): () =>
                      _indentSelection(false),
                  const SingleActivator(LogicalKeyboardKey.tab, shift: true):
                      () => _indentSelection(true),
                  const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                      _openLinkDialog,
                  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                      _openLinkDialog,
                  // Smart paste: wrap selection as [sel](url) when the
                  // clipboard text looks like a URL; otherwise behaves
                  // exactly like the platform's plain-text paste.
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                      _smartPaste,
                  const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                      _smartPaste,
                  // Sort lines touched by the selection (case-insensitive
                  // ascending). Same shortcut VS Code uses for "Sort
                  // Lines Ascending".
                  const SingleActivator(LogicalKeyboardKey.keyS,
                      meta: true, shift: true): _sortSelectedLines,
                  const SingleActivator(LogicalKeyboardKey.keyS,
                      control: true, shift: true): _sortSelectedLines,
                  // Deduplicate the lines in the selection — case-
                  // sensitive, keeps first occurrence. ⌘⌥D.
                  const SingleActivator(LogicalKeyboardKey.keyD,
                      meta: true, alt: true): _dedupeSelectedLines,
                  const SingleActivator(LogicalKeyboardKey.keyD,
                      control: true, alt: true): _dedupeSelectedLines,
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  maxLines: null,
                  minLines: 8,
                  readOnly: widget.locked,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.locked
                        ? 'Page is locked · unlock to edit'
                        : 'Type / for the slash menu, or markdown directly',
                    hintStyle:
                        mono(fontSize: 13.5, color: tokens.text3),
                  ),
                  style: mono(fontSize: 13.5, color: tokens.text)
                      .copyWith(height: 1.65),
                ),
              ),
            ),
          ),
          // Positioned.fill bounds the overlay Stack to the field's box,
          // so its inner Stack (Positioned-only children) can compute a
          // finite size. clipBehavior: Clip.none on the inner Stack lets
          // the panel render outside the field bounds if the caret is
          // near the bottom.
          Positioned.fill(
            child: RelationPickerOverlay(
              onPick: _onPick,
              onDismiss: () {
                _triggerStart = null;
                _picker.dismiss();
              },
            ),
          ),
          Positioned.fill(
            child: SlashMenuOverlay(
              onPick: _onSlashPick,
              onDismiss: () {
                _slashTriggerStart = null;
                _slash.dismiss();
              },
            ),
          ),
        ],
      ),
    );
  }
}
