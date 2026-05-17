import 'package:flutter/material.dart';

/// H3a — extracts the editor's M85 find-in-page state machine out
/// of `_EditorBodyState`. The host owns one instance per editor
/// mount and listens via `addListener` for rebuild signals; the
/// controller's [queryController] / [focusNode] are wired into
/// the `_FindBar` widget directly.
///
/// State surface:
/// - [isOpen]: whether the find bar is mounted in the editor body.
/// - [queryController]: TextEditingController behind the find input.
/// - [focusNode]: FocusNode for the find input.
/// - [matches]: line indices of the body where the query is found.
///   Each line counts at most once, even if the query appears
///   multiple times on the same line.
/// - [cursor]: index into [matches] for the currently-highlighted
///   hit. Wraps modulo [matches.length] under [step].
///
/// Scroll integration is opt-in via the constructor's [scroll]
/// argument. The controller computes the target offset using the
/// same `(lineIdx / totalLines) * maxScrollExtent` heuristic the
/// pre-extraction inline code used; if [scroll.hasClients] is
/// false (e.g. in tests, or before the body lays out) the animate
/// call is silently skipped.
class FindInPageController extends ChangeNotifier {
  FindInPageController({required ScrollController scroll}) : _scroll = scroll;

  final ScrollController _scroll;
  final TextEditingController queryController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  bool _isOpen = false;
  List<int> _matches = const [];
  int _cursor = 0;

  bool get isOpen => _isOpen;
  List<int> get matches => _matches;
  int get cursor => _cursor;

  /// Open the find bar. Idempotent — a second open() while already
  /// open is a no-op and does NOT re-notify listeners. Schedules a
  /// post-frame focus + select-all on [queryController] so the user
  /// can immediately overtype the previous query.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
      queryController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: queryController.text.length,
      );
    });
  }

  /// Close the find bar and clear current matches + cursor.
  void close() {
    _isOpen = false;
    _matches = const [];
    _cursor = 0;
    notifyListeners();
  }

  /// Re-scan [body] for [queryController.text]. Match policy:
  /// case-insensitive; whitespace-trimmed; per-line dedup (each
  /// line counts at most once); empty query clears matches.
  void recompute(String body) {
    final q = queryController.text.trim();
    if (q.isEmpty) {
      _matches = const [];
      _cursor = 0;
      notifyListeners();
      return;
    }
    final lower = body.toLowerCase();
    final needle = q.toLowerCase();
    final hits = <int>[];
    var searchFrom = 0;
    while (true) {
      final idx = lower.indexOf(needle, searchFrom);
      if (idx < 0) break;
      final before = body.substring(0, idx);
      final lineIdx = '\n'.allMatches(before).length;
      if (hits.isEmpty || hits.last != lineIdx) hits.add(lineIdx);
      searchFrom = idx + needle.length;
    }
    _matches = hits;
    _cursor = 0;
    notifyListeners();
    if (hits.isNotEmpty) {
      _scrollToMatch(body.split('\n').length);
    }
  }

  /// Move the cursor by [delta] (positive forward, negative
  /// backward), wrapping modulo [matches.length]. Silent no-op
  /// when no matches.
  void step(int delta, String body) {
    if (_matches.isEmpty) return;
    final next = (_cursor + delta) % _matches.length;
    _cursor = next < 0 ? next + _matches.length : next;
    notifyListeners();
    _scrollToMatch(body.split('\n').length);
  }

  void _scrollToMatch(int totalLines) {
    if (_matches.isEmpty || !_scroll.hasClients) return;
    final lineIdx = _matches[_cursor];
    final frac = totalLines == 0 ? 0.0 : lineIdx / totalLines;
    final pos = _scroll.position;
    final target = (pos.maxScrollExtent * frac)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    pos.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    queryController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
