import 'package:flutter/widgets.dart';

import 'anchor_rect.dart';

/// Bridge between Flutter's [Rect] and the plain-Dart [AnchorRect] that
/// cubits use to anchor overlays. Keeping this conversion in a single
/// place lets both source-mode (`SourceView._caretRect()`) and the
/// upcoming WYSIWYG positioning (`EditorBetaPage` slice 2f) hand off
/// caret-rect math identically.
///
/// Pure mapping — no clamping, no DPI conversion. Callers that need to
/// clamp against a parent width / clip to a viewport do that before
/// reaching here.
AnchorRect anchorRectFromRect(Rect rect) => AnchorRect(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
    );

/// Sugar that lets `someRect.toAnchor()` read naturally at the call
/// site. Equivalent to [anchorRectFromRect].
extension RectAnchor on Rect {
  /// Convert this Flutter [Rect] to the plain-Dart [AnchorRect].
  AnchorRect toAnchor() => anchorRectFromRect(this);
}
