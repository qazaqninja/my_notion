import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../sync/domain/entities/awareness_message.dart';
import '../../../sync/presentation/cubit/presence_cubit.dart';

/// Named fallback for the peer-cursor chiclet when
/// [AwarenessMessage.color] doesn't parse as `#RRGGBB`. Lives at
/// file-scope rather than QuillTokens because (a) it's a defensive
/// sentinel rather than a theme color, and (b) the H4d wire path
/// rejects malformed messages earlier so this should never paint
/// in the happy path. M1455 TH-03 fix-forward (per orchestrator
/// guidance, lifted out of the inline `_parseColor` body).
const _peerCursorColorFallback = Color(0xFF888888);

/// Function that maps a character offset in the source-mode body
/// to a screen-space rect for the caret at that index. Provided
/// by the editor — H4d wires it through from the TextField's
/// `RenderEditable.getRectForComposingRange` (or, for a single
/// caret, [RenderEditable.getLocalRectForCaret]). Returns null if
/// the index is out of range so the overlay can drop that
/// chiclet without painting an off-screen tag.
typedef CursorRectResolver = Rect? Function(int charIndex);

/// H4c — paints other-user cursors over the editor body. Consumes
/// [PresenceCubit] via [BlocBuilder]: one chiclet per peer entry,
/// positioned at the rect returned by [cursorRectAt]. Chiclet =
/// 2-px-wide colored bar + 12-px-tall colored label rect anchored
/// at the bar's top.
///
/// State-free; rebuild is driven entirely by [PresenceState]
/// transitions. Empty cursor map → an empty Stack (still rendered
/// so callers can keep the widget mounted while peers come and
/// go).
///
/// H4d follow-up wires the resolver to the live TextField in
/// `_EditorBodyState`. This slice just owns the visual layer.
class RemoteCursorOverlay extends StatelessWidget {
  const RemoteCursorOverlay({
    super.key,
    required this.cursorRectAt,
  });

  /// Editor-supplied caret-rect resolver. See [CursorRectResolver].
  final CursorRectResolver cursorRectAt;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PresenceCubit, PresenceState>(
      // Today PresenceState only carries the cursors map, but
      // explicit buildWhen narrows the rebuild scope so future
      // additions (e.g. local-cursor color, viewer count) don't
      // accidentally repaint the chiclets. M1455 BL-12 fix-forward.
      buildWhen: (prev, next) => prev.cursors != next.cursors,
      builder: (context, state) {
        final chiclets = <Widget>[];
        for (final entry in state.cursors.entries) {
          final rect = cursorRectAt(entry.value.cursorIndex);
          if (rect == null) continue;
          chiclets.add(_RemoteCursorChiclet(
            key: ValueKey('remote-cursor-${entry.key}'),
            rect: rect,
            message: entry.value,
          ));
        }
        return IgnorePointer(
          // The overlay is purely visual — taps fall through to
          // the underlying TextField. Don't intercept input.
          child: Stack(children: chiclets),
        );
      },
    );
  }
}

class _RemoteCursorChiclet extends StatelessWidget {
  const _RemoteCursorChiclet({super.key, required this.rect, required this.message});

  final Rect rect;
  final AwarenessMessage message;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(message.color);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: 2,
      height: rect.height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(1)),
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: Transform.translate(
            // Pin the label above the caret, anchored to the bar's
            // right edge so it doesn't visually slide left as the
            // bar's width animates.
            offset: const Offset(0, -14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
              child: Text(
                _shortLabel(message.userId),
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Best-effort `#RRGGBB` parse. Falls back to
  /// [_peerCursorColorFallback] on malformed input so a misbehaving
  /// peer can't crash the overlay.
  static Color _parseColor(String hex) {
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length != 6) return _peerCursorColorFallback;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return _peerCursorColorFallback;
    return Color(0xFF000000 | v);
  }

  /// Short label = first 4 chars of the userId. ULIDs are 26
  /// chars; rendering the whole thing would dwarf the chiclet.
  /// Future work could resolve to a display name via the
  /// WorkspaceConfig.users list once H4d wires that through.
  static String _shortLabel(String userId) {
    if (userId.length <= 4) return userId;
    return userId.substring(0, 4);
  }
}
