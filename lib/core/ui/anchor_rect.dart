/// Plain-Dart rectangle used to anchor floating overlays (slash menu,
/// relation picker) to a source position. Mirrors the shape of
/// `package:flutter/material.dart` `Rect` so the conversion at the
/// widget-layer boundary is mechanical, but keeps the bloc/cubit layer
/// pure Dart per CA-01 in docs/RULES.md.
class AnchorRect {
  const AnchorRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory AnchorRect.fromLTWH(double left, double top, double width, double height) =>
      AnchorRect(left: left, top: top, right: left + width, bottom: top + height);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnchorRect &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'AnchorRect($left, $top → $right, $bottom)';
}
