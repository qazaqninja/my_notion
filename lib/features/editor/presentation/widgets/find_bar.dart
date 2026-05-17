import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';

/// Slim, callback-driven find-in-page bar shown at the bottom of the
/// editor body when the user opens find-in-page (⌘F in legacy mode;
/// AppBar `IconButton(Icons.search)` in EditorBetaPage).
///
/// 1:1 port of the legacy `_FindBar` (private widget at
/// `editor_page.dart:2040`) to a public reusable widget so the new
/// `/editor-beta` route can mount the same surface. All state
/// (controller, matches/cursor counts) is supplied by the parent —
/// the bar is intentionally stateless so the parent's editor
/// controller can drive the search loop and dispatch
/// [selectionRequestForMatch] via super_editor's RequestDispatcher.
///
/// Slice 3a of the D-fp4 Find-in-Page port. Slice 3b will wire this
/// widget into [EditorBetaPage] AppBar (toggle visibility, autofocus
/// the TextField) + driver logic that calls `findMatches` on every
/// query change and dispatches `selectionRequestForMatch(cursor.current)`
/// via the editor's `RequestDispatcher`.
class FindBar extends StatelessWidget {
  /// Construct a find bar wired to the parent-owned [controller] +
  /// [focusNode]. The [matches] / [cursor] numbers are the bar's
  /// label text inputs; navigation buttons disable when matches == 0.
  const FindBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.matches,
    required this.cursor,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  /// Owned by the parent — the bar mirrors the query into this
  /// controller via `TextField.controller` so live-edits stay in
  /// sync with whatever the parent runs `findMatches()` against.
  final TextEditingController controller;

  /// Owned by the parent — let it call `focusNode.requestFocus()`
  /// after slice 3b mounts the bar so the user can start typing
  /// immediately.
  final FocusNode focusNode;

  /// Total number of matches in the current page. Drives the
  /// "no matches" / "N / M" label.
  final int matches;

  /// 1-based cursor position into [matches]. The bar displays
  /// "$cursor / $matches" verbatim; out-of-range values are the
  /// parent's responsibility (use M1629's `MatchCursor.index + 1`
  /// when active, `0` when empty).
  final int cursor;

  /// Fires on every query keystroke. Parent re-runs `findMatches`.
  final ValueChanged<String> onChanged;

  /// Fires on previous-match button tap or Shift+Enter on the field.
  final VoidCallback onPrev;

  /// Fires on next-match button tap, Enter on the field, or ⌘G.
  final VoidCallback onNext;

  /// Fires on the close (×) button tap or Esc on the field.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final hasMatches = matches > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 14, color: tokens.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onNext(),
              style: TextStyle(fontSize: 13, color: tokens.text),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                hintText: 'Find in page…',
                hintStyle: TextStyle(fontSize: 12.5, color: tokens.text3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: !hasMatches
                ? 'No matches in this page'
                : 'Match $cursor of '
                    '${matches == 1 ? "1 match" : "$matches matches"}',
            waitDuration: const Duration(milliseconds: 500),
            child: Text(
              !hasMatches ? 'no matches' : '$cursor / $matches',
              style: mono(fontSize: 11.5, color: tokens.text3),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: hasMatches ? onPrev : null,
            icon: Icon(
              Icons.keyboard_arrow_up,
              size: 16,
              color: tokens.text2,
            ),
            tooltip: 'Previous match (⌘⇧G)',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: hasMatches ? onNext : null,
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: tokens.text2,
            ),
            tooltip: 'Next match (⌘G)',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: onClose,
            icon: Icon(Icons.close, size: 14, color: tokens.text3),
            tooltip: 'Close (Esc)',
          ),
        ],
      ),
    );
  }
}
